from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional, Tuple
import uuid

from google.cloud import firestore

from .firebase_service import get_firestore_client


def _now_ts() -> datetime:
    return datetime.now(timezone.utc)


def _chunk(items: List[Any], size: int) -> List[List[Any]]:
    return [items[i : i + size] for i in range(0, len(items), size)]


def _determine_stage(grade_level: int) -> str:
    if 1 <= grade_level <= 6:
        return "primary"
    if 7 <= grade_level <= 9:
        return "middle"
    if 10 <= grade_level <= 12:
        return "secondary"
    return "unknown"


def _stage_year(grade_level: int) -> int:
    stage = _determine_stage(grade_level)
    if stage == "primary":
        return max(1, min(6, grade_level))
    if stage == "middle":
        return max(1, min(3, grade_level - 6))
    if stage == "secondary":
        return max(1, min(3, grade_level - 9))
    return 1


def _seat_start(grade_level: int) -> int:
    y = _stage_year(grade_level)
    return y * 1000 + 1


def _choose_columns(n: int) -> int:
    if n == 36:
        return 6
    if n <= 36 and n % 6 == 0:
        return 6
    if n % 5 == 0:
        return 5
    if n <= 36:
        r5 = (n + 4) // 5
        r6 = (n + 5) // 6
        if r6 < r5:
            return 6
    return 5


@dataclass(frozen=True)
class StudentRecord:
    student_id: str
    student_name: str
    class_id: str
    class_name: str
    grade_level: int


@dataclass(frozen=True)
class RoomRecord:
    room_id: str
    room_name: str
    room_type: str  # classroom | lab | overflow
    exam_capacity: int
    priority: int
    available_for_exam: bool


class ExamSeatingService:
    def __init__(self) -> None:
        self.db = get_firestore_client()

    def _policy_ref(self, school_id: str, session_id: str) -> Tuple[str, Dict[str, Any]]:
        session_doc = self.db.collection("examSessions").document(session_id).get()
        if not session_doc.exists:
            raise ValueError("session_not_found")
        session = session_doc.to_dict() or {}
        policy_id = (session.get("policyId") or "").strip()
        if policy_id:
            doc = self.db.collection("examSeatingPolicy").document(policy_id).get()
            if doc.exists:
                return policy_id, (doc.to_dict() or {})
        doc = self.db.collection("examSeatingPolicy").document(school_id).get()
        if doc.exists:
            return school_id, (doc.to_dict() or {})
        default = {
            "preserveHomeClassroom": True,
            "classroomCapacity": 35,
            "labCapacity": 55,
            "overflowEnabled": True,
            "mixOverflowStudents": True,
            "useLabsBeforeOverflow": True,
            "distributeOnlyExcessStudents": True,
        }
        self.db.collection("examSeatingPolicy").document(school_id).set(
            {"schoolId": school_id, **default, "updatedAt": firestore.SERVER_TIMESTAMP},
            merge=True,
        )
        return school_id, default

    def create_session(self, school_id: str, payload: Dict[str, Any]) -> str:
        session_id = (payload.get("sessionId") or "").strip() or uuid.uuid4().hex
        policy_id = (payload.get("policyId") or "").strip()
        self.db.collection("examSessions").document(session_id).set(
            {
                "id": session_id,
                "schoolId": school_id,
                "status": "active",
                "policyId": policy_id if policy_id else None,
                "createdAt": firestore.SERVER_TIMESTAMP,
                "updatedAt": firestore.SERVER_TIMESTAMP,
            },
            merge=True,
        )
        return session_id

    def _load_students(self, school_id: str) -> List[StudentRecord]:
        classes_snap = (
            self.db.collection("Schools").document(school_id).collection("Classes").get()
        )
        classes: List[Tuple[str, Dict[str, Any]]] = []
        class_by_id: Dict[str, Dict[str, Any]] = {}
        class_name_to_id: Dict[str, str] = {}
        fallback_student_ids: List[str] = []
        for doc in classes_snap:
            data = doc.to_dict() or {}
            class_id = (data.get("id") or doc.id or "").strip()
            if not class_id:
                continue
            class_by_id[class_id] = data
            student_list = data.get("studentIds") or []
            if not isinstance(student_list, list):
                student_list = []
            student_list = [str(x).strip() for x in student_list if str(x).strip()]
            classes.append((class_id, data))
            fallback_student_ids.extend(student_list)
            name = (data.get("name") or data.get("displayName") or "").strip()
            if name:
                class_name_to_id[name] = class_id

        students_snap = (
            self.db.collection("Schools").document(school_id).collection("Students").get()
        )

        out: List[StudentRecord] = []
        seen: set[str] = set()

        if students_snap:
            for d in students_snap:
                data = d.to_dict() or {}
                sid = (d.id or "").strip()
                if not sid or sid in seen:
                    continue

                class_id = ""
                assigned = data.get("assignedClassIds") or []
                if isinstance(assigned, list):
                    assigned = [str(x).strip() for x in assigned if str(x).strip()]
                else:
                    assigned = []
                if assigned:
                    class_id = assigned[0]
                else:
                    class_id = str(data.get("classId") or "").strip()

                if not class_id:
                    cn = str(data.get("className") or data.get("class") or "").strip()
                    if cn:
                        class_id = class_name_to_id.get(cn, "")

                if not class_id:
                    continue

                c = class_by_id.get(class_id) or {}
                class_name = str(c.get("name") or c.get("displayName") or data.get("className") or class_id).strip()
                grade_level = int(c.get("gradeLevel") or data.get("gradeLevel") or 0)
                if grade_level <= 0:
                    continue
                name = str(data.get("name") or sid).strip()
                out.append(
                    StudentRecord(
                        student_id=sid,
                        student_name=name,
                        class_id=class_id,
                        class_name=class_name,
                        grade_level=grade_level,
                    )
                )
                seen.add(sid)

        if not out and fallback_student_ids:
            if not classes:
                raise ValueError("no_students")
            unique_student_ids = sorted(list({sid for sid in fallback_student_ids if sid}))
            students_by_id: Dict[str, Dict[str, Any]] = {}
            for chunk_ids in _chunk(unique_student_ids, 400):
                docs = self.db.get_all(
                    [
                        self.db.collection("Schools")
                        .document(school_id)
                        .collection("Students")
                        .document(sid)
                        for sid in chunk_ids
                    ]
                )
                for d in docs:
                    if d.exists:
                        students_by_id[d.id] = d.to_dict() or {}

            for class_id, c in classes:
                class_name = (c.get("name") or c.get("displayName") or class_id).strip()
                grade_level = int(c.get("gradeLevel") or 0)
                student_list = c.get("studentIds") or []
                if not isinstance(student_list, list):
                    continue
                for sid in student_list:
                    sid2 = str(sid).strip()
                    if not sid2 or sid2 in seen:
                        continue
                    s = students_by_id.get(sid2) or {}
                    name = (s.get("name") or sid2).strip()
                    if grade_level <= 0:
                        continue
                    out.append(
                        StudentRecord(
                            student_id=sid2,
                            student_name=name,
                            class_id=class_id,
                            class_name=class_name,
                            grade_level=grade_level,
                        )
                    )
                    seen.add(sid2)

        if not out:
            raise ValueError("no_students")

        out.sort(key=lambda x: (x.grade_level, x.class_name, x.student_name, x.student_id))
        return out

    def _load_rooms(self, school_id: str, policy: Dict[str, Any]) -> List[RoomRecord]:
        snap = (
            self.db.collection("examRoomLayouts")
            .where("schoolId", "==", school_id)
            .get()
        )
        rooms: List[RoomRecord] = []
        for doc in snap:
            data = doc.to_dict() or {}
            room_id = (data.get("roomId") or doc.id or "").strip()
            room_name = (data.get("roomName") or room_id).strip()
            room_type = (data.get("roomType") or "classroom").strip()
            cap = int(data.get("examCapacity") or 0)
            pr = int(data.get("priority") or 1000)
            avail = bool(data.get("availableForExam") if "availableForExam" in data else True)
            if cap <= 0:
                if room_type == "lab":
                    cap = int(policy.get("labCapacity") or 55)
                else:
                    cap = int(policy.get("classroomCapacity") or 35)
            rooms.append(
                RoomRecord(
                    room_id=room_id,
                    room_name=room_name,
                    room_type=room_type,
                    exam_capacity=cap,
                    priority=pr,
                    available_for_exam=avail,
                )
            )
        rooms = [r for r in rooms if r.room_id and r.available_for_exam]
        rooms.sort(key=lambda r: (r.priority, r.room_type, r.room_name))
        return rooms

    def generate_seat_numbers(self, school_id: str, session_id: str) -> Dict[str, Any]:
        students = self._load_students(school_id)
        by_grade: Dict[int, List[StudentRecord]] = {}
        for s in students:
            by_grade.setdefault(s.grade_level, []).append(s)

        writes: List[Tuple[str, Dict[str, Any]]] = []
        for grade, group in sorted(by_grade.items(), key=lambda x: x[0]):
            start = _seat_start(grade)
            current = start
            for s in group:
                seat_number = current
                current += 1
                doc_id = f"{session_id}_{s.student_id}"
                writes.append(
                    (
                        doc_id,
                        {
                            "id": doc_id,
                            "schoolId": school_id,
                            "sessionId": session_id,
                            "studentId": s.student_id,
                            "studentName": s.student_name,
                            "classId": s.class_id,
                            "className": s.class_name,
                            "gradeLevel": s.grade_level,
                            "stage": _determine_stage(s.grade_level),
                            "seatNumber": seat_number,
                            "createdAt": firestore.SERVER_TIMESTAMP,
                            "updatedAt": firestore.SERVER_TIMESTAMP,
                        },
                    )
                )

        for chunk_writes in _chunk(writes, 450):
            batch = self.db.batch()
            for doc_id, data in chunk_writes:
                ref = self.db.collection("examSeatNumbers").document(doc_id)
                batch.set(ref, data, merge=True)
            batch.commit()

        self.db.collection("examSessions").document(session_id).set(
            {
                "updatedAt": firestore.SERVER_TIMESTAMP,
                "seatNumbersGeneratedAt": firestore.SERVER_TIMESTAMP,
                "seatNumbersCount": len(writes),
            },
            merge=True,
        )
        return {"sessionId": session_id, "count": len(writes)}

    def generate_committees(self, school_id: str, session_id: str) -> Dict[str, Any]:
        policy_id, policy = self._policy_ref(school_id, session_id)
        students = self._load_students(school_id)
        rooms = self._load_rooms(school_id, policy)

        preserve = bool(policy.get("preserveHomeClassroom") if "preserveHomeClassroom" in policy else True)
        classroom_capacity = int(policy.get("classroomCapacity") or 35)
        lab_capacity = int(policy.get("labCapacity") or 55)
        overflow_enabled = bool(policy.get("overflowEnabled") if "overflowEnabled" in policy else True)
        mix_overflow = bool(policy.get("mixOverflowStudents") if "mixOverflowStudents" in policy else True)
        use_labs_first = bool(policy.get("useLabsBeforeOverflow") if "useLabsBeforeOverflow" in policy else True)
        only_excess = bool(policy.get("distributeOnlyExcessStudents") if "distributeOnlyExcessStudents" in policy else True)

        classroom_rooms = [r for r in rooms if r.room_type == "classroom"]
        lab_rooms = [r for r in rooms if r.room_type == "lab"]
        overflow_rooms = [r for r in rooms if r.room_type == "overflow"]

        by_class: Dict[str, List[StudentRecord]] = {}
        class_name: Dict[str, str] = {}
        grade_by_class: Dict[str, int] = {}
        for s in students:
            by_class.setdefault(s.class_id, []).append(s)
            class_name[s.class_id] = s.class_name
            grade_by_class[s.class_id] = s.grade_level
        for cid in by_class.keys():
            by_class[cid].sort(key=lambda x: (x.student_name, x.student_id))

        committees: List[Dict[str, Any]] = []
        excess_students: List[StudentRecord] = []

        def _make_committee(room: RoomRecord, student_ids: List[str], home_class_ids: List[str]) -> Dict[str, Any]:
            cid = uuid.uuid4().hex
            return {
                "id": cid,
                "schoolId": school_id,
                "sessionId": session_id,
                "committeeId": cid,
                "roomId": room.room_id,
                "roomName": room.room_name,
                "roomType": room.room_type,
                "examCapacity": room.exam_capacity,
                "priority": room.priority,
                "studentIds": student_ids,
                "homeClassIds": home_class_ids,
                "createdAt": firestore.SERVER_TIMESTAMP,
                "updatedAt": firestore.SERVER_TIMESTAMP,
            }

        def _room_for_class(cid: str) -> Optional[RoomRecord]:
            for r in classroom_rooms:
                if r.room_id == cid:
                    return r
            cname = class_name.get(cid, "")
            if cname:
                for r in classroom_rooms:
                    if cname in r.room_name:
                        return r
            return None

        if preserve:
            for cid, group in sorted(by_class.items(), key=lambda x: (grade_by_class.get(x[0], 0), class_name.get(x[0], x[0]))):
                room = _room_for_class(cid)
                if room is None:
                    room = RoomRecord(
                        room_id=cid,
                        room_name=class_name.get(cid, cid),
                        room_type="classroom",
                        exam_capacity=classroom_capacity,
                        priority=100,
                        available_for_exam=True,
                    )
                cap = room.exam_capacity if room.exam_capacity > 0 else classroom_capacity
                keep = group if not only_excess else group[: min(len(group), cap)]
                move = [] if not only_excess else group[min(len(group), cap) :]
                if keep:
                    committees.append(_make_committee(room, [s.student_id for s in keep], [cid]))
                excess_students.extend(move)
        else:
            excess_students = list(students)

        def _alloc_rooms(target_rooms: List[RoomRecord], pool: List[StudentRecord], allow_mix: bool) -> List[Dict[str, Any]]:
            result: List[Dict[str, Any]] = []
            if not pool:
                return result
            if allow_mix:
                remaining = list(pool)
                for r in target_rooms:
                    if not remaining:
                        break
                    cap = r.exam_capacity
                    take = remaining[: min(len(remaining), cap)]
                    remaining = remaining[min(len(remaining), cap) :]
                    result.append(_make_committee(r, [s.student_id for s in take], sorted(list({s.class_id for s in take}))))
                pool[:] = remaining
                return result
            else:
                byc: Dict[str, List[StudentRecord]] = {}
                for s in pool:
                    byc.setdefault(s.class_id, []).append(s)
                pool.clear()
                for cid, group in byc.items():
                    remaining = group
                    for r in target_rooms:
                        if not remaining:
                            break
                        cap = r.exam_capacity
                        take = remaining[: min(len(remaining), cap)]
                        remaining = remaining[min(len(remaining), cap) :]
                        result.append(_make_committee(r, [s.student_id for s in take], [cid]))
                    pool.extend(remaining)
                return result

        if excess_students:
            labs_first = use_labs_first
            if labs_first and lab_rooms:
                for r in lab_rooms:
                    if r.exam_capacity <= 0:
                        r = RoomRecord(
                            room_id=r.room_id,
                            room_name=r.room_name,
                            room_type=r.room_type,
                            exam_capacity=lab_capacity,
                            priority=r.priority,
                            available_for_exam=r.available_for_exam,
                        )
                committees.extend(_alloc_rooms(lab_rooms, excess_students, mix_overflow))

            if excess_students and overflow_enabled:
                if not overflow_rooms:
                    overflow_rooms = [
                        RoomRecord(
                            room_id="overflow_1",
                            room_name="قاعة إضافية",
                            room_type="overflow",
                            exam_capacity=classroom_capacity,
                            priority=900,
                            available_for_exam=True,
                        )
                    ]
                committees.extend(_alloc_rooms(overflow_rooms, excess_students, mix_overflow))

        self._replace_session_committees(school_id, session_id, committees)

        self.db.collection("examSessions").document(session_id).set(
            {
                "updatedAt": firestore.SERVER_TIMESTAMP,
                "committeesGeneratedAt": firestore.SERVER_TIMESTAMP,
                "committeesCount": len(committees),
                "policyIdResolved": policy_id,
            },
            merge=True,
        )
        return {"sessionId": session_id, "count": len(committees), "unassigned": len(excess_students)}

    def _replace_session_committees(self, school_id: str, session_id: str, committees: List[Dict[str, Any]]) -> None:
        existing = (
            self.db.collection("examCommittees")
            .where("schoolId", "==", school_id)
            .where("sessionId", "==", session_id)
            .get()
        )
        for chunk_docs in _chunk(list(existing), 450):
            batch = self.db.batch()
            for d in chunk_docs:
                batch.delete(d.reference)
            batch.commit()

        for chunk_committees in _chunk(committees, 450):
            batch = self.db.batch()
            for c in chunk_committees:
                ref = self.db.collection("examCommittees").document(c["id"])
                batch.set(ref, c, merge=True)
            batch.commit()

    def assign_seats(self, school_id: str, session_id: str, payload: Dict[str, Any]) -> Dict[str, Any]:
        committees_snap = (
            self.db.collection("examCommittees")
            .where("schoolId", "==", school_id)
            .where("sessionId", "==", session_id)
            .get()
        )
        committees = [d.to_dict() or {} for d in committees_snap]
        committees = [c for c in committees if c.get("studentIds")]
        committees.sort(key=lambda c: (c.get("priority", 1000), c.get("roomType", ""), c.get("roomName", "")))

        assignments: List[Tuple[str, Dict[str, Any]]] = []
        updates: List[Tuple[str, Dict[str, Any]]] = []

        for c in committees:
            student_ids = [str(x).strip() for x in (c.get("studentIds") or []) if str(x).strip()]
            if not student_ids:
                continue
            cols = _choose_columns(len(student_ids))
            for idx, sid in enumerate(student_ids):
                seat_index = idx + 1
                row_index = idx // cols
                col_index = idx % cols
                doc_id = f"{session_id}_{sid}"
                a_doc_id = f"{session_id}_{sid}"
                assignments.append(
                    (
                        a_doc_id,
                        {
                            "id": a_doc_id,
                            "schoolId": school_id,
                            "sessionId": session_id,
                            "studentId": sid,
                            "committeeId": c.get("committeeId") or c.get("id"),
                            "roomId": c.get("roomId"),
                            "roomName": c.get("roomName"),
                            "roomType": c.get("roomType"),
                            "seatIndex": seat_index,
                            "rowIndex": row_index,
                            "columnIndex": col_index,
                            "createdAt": firestore.SERVER_TIMESTAMP,
                            "updatedAt": firestore.SERVER_TIMESTAMP,
                        },
                    )
                )
                updates.append(
                    (
                        doc_id,
                        {
                            "committeeId": c.get("committeeId") or c.get("id"),
                            "seatIndex": seat_index,
                            "rowIndex": row_index,
                            "columnIndex": col_index,
                            "updatedAt": firestore.SERVER_TIMESTAMP,
                        },
                    )
                )

        for chunk_a in _chunk(assignments, 450):
            batch = self.db.batch()
            for doc_id, data in chunk_a:
                ref = self.db.collection("examSeatAssignments").document(doc_id)
                batch.set(ref, data, merge=True)
            batch.commit()

        for chunk_u in _chunk(updates, 450):
            batch = self.db.batch()
            for doc_id, data in chunk_u:
                ref = self.db.collection("examSeatNumbers").document(doc_id)
                batch.set(ref, data, merge=True)
            batch.commit()

        self.db.collection("examSessions").document(session_id).set(
            {
                "updatedAt": firestore.SERVER_TIMESTAMP,
                "seatAssignmentsGeneratedAt": firestore.SERVER_TIMESTAMP,
                "seatAssignmentsCount": len(assignments),
            },
            merge=True,
        )
        return {"sessionId": session_id, "count": len(assignments)}

    def get_session(self, session_id: str) -> Dict[str, Any]:
        doc = self.db.collection("examSessions").document(session_id).get()
        if not doc.exists:
            raise ValueError("session_not_found")
        return doc.to_dict() or {}

    def get_committee(self, committee_id: str) -> Dict[str, Any]:
        doc = self.db.collection("examCommittees").document(committee_id).get()
        if not doc.exists:
            raise ValueError("committee_not_found")
        return doc.to_dict() or {}

    def regenerate(self, school_id: str, session_id: str) -> Dict[str, Any]:
        for col in ["examSeatAssignments", "examSeatNumbers", "examCommittees"]:
            q = (
                self.db.collection(col)
                .where("schoolId", "==", school_id)
                .where("sessionId", "==", session_id)
                .get()
            )
            docs = list(q)
            for chunk_docs in _chunk(docs, 450):
                batch = self.db.batch()
                for d in chunk_docs:
                    batch.delete(d.reference)
                batch.commit()
        self.db.collection("examSessions").document(session_id).set(
            {"updatedAt": firestore.SERVER_TIMESTAMP, "status": "active"},
            merge=True,
        )
        self.generate_seat_numbers(school_id, session_id)
        self.generate_committees(school_id, session_id)
        self.assign_seats(school_id, session_id, {})
        return {"sessionId": session_id, "status": "regenerated"}
