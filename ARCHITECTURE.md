# Masar System Architecture & Specification

## 1. Overview
**System Name:** Masar – Student Tracking & Discipline System  
**Goal:** A comprehensive smart system for managing attendance, behavior, discipline, commitments, and communication with strict Role-Based Access Control (RBAC).

## 2. Technology Stack
*   **Framework:** Flutter (Mobile + Web)
*   **Architecture:** Clean Architecture
*   **State Management:** Riverpod
*   **Language:** Dart

## 3. Role-Based Access Control (RBAC) - Strict Separation

| Role | Access Level | Key Features |
| :--- | :--- | :--- |
| **Principal** (المدير) | Full Access | All Panels + **Add Deputy** (Exclusive) |
| **Vice Principal** (الوكيل) | Operational Admin | All Operational Panels (Cannot change system settings) |
| **Teacher** (المعلم) | Class Level | My Classes, Attendance, Behavior, Assignments |
| **Counselor** (المرشد) | Counseling Panel | Behavior, Absence, Commitments, Sessions, Behavior Plans |
| **Admin Staff** (الإداري) | Admin Panel | Outgoing/Incoming Mail, Files (No access to Behavior/Grades) |
| **Parent** (ولي الأمر) | Child Level | View Child's Behavior, Absence, Alerts, Comm. with School |
| **Student** (الطالب) | Personal Level | Assignments, Commitments, Behavior Bar |

## 4. Domain Models & Schema

### 4.1 Users
*   `id`: UUID
*   `name`: String
*   `role`: Enum (principal, deputy, teacher, counselor, administrative, parent, student)
*   `email`: String
*   `password_hash`: String

### 4.2 Discipline & Behavior (Behavior Center)
*   **Entity:** `Violation`
    *   `id`: UUID
    *   `studentId`: UUID
    *   `teacherId`: UUID
    *   `type`: Enum (minor, moderate, major)
    *   `description`: String
    *   `timestamp`: DateTime
    *   `status`: Enum (active, closed, archived)
    *   `pointsDeducted`: Int

*   **Logic:**
    *   1st Offense: Warning
    *   2nd Offense: Points Deduction + Parent Notification
    *   3rd Offense: Digital Commitment
    *   4th Offense: Referral to Counselor

### 4.3 Digital Commitments
*   **Entity:** `Commitment`
    *   `id`: UUID
    *   `studentId`: UUID
    *   `type`: Enum (behavioral, disciplinary, academic)
    *   `createdDate`: DateTime
    *   `status`: Enum (active, expired, violated)
    *   `studentSignature`: Boolean/Timestamp
    *   `parentApproval`: Boolean/Timestamp

### 4.4 Counseling
*   **Entity:** `CounselingSession`
    *   `id`: UUID
    *   `studentId`: UUID
    *   `counselorId`: UUID
    *   `date`: DateTime
    *   `notes`: String (Encrypted/Private)
    *   `recommendations`: String

### 4.5 Smart Attendance
*   **Entity:** `AttendanceRecord`
    *   `id`: UUID
    *   `studentId`: UUID
    *   `date`: Date
    *   `status`: Enum (present, absent, late, excused)
    *   `checkInTime`: DateTime
    *   `method`: Enum (qr, manual, admin_override)

## 5. Directory Structure (Clean Architecture)
```
lib/src/
  ├── core/                 # Shared Kernel
  ├── features/
  │   ├── auth/             # Login & RBAC
  │   ├── dashboard/        # Role-Specific Dashboards
  │   ├── behavior/         # Violations, Points, Commitments
  │   ├── academic/         # Classes, Assignments
  │   ├── attendance/       # Smart Attendance
  │   └── counseling/       # Sessions, Plans
```

## 6. Business Rules Engine
*   **Lateness:** If `checkInTime` > `startTime` -> Status `Late` -> Deduct Points -> Notify Parent.
*   **Escalation:** If `violationCount` > 3 -> Create `Commitment` Task.
*   **Commitment Breach:** If `Commitment` violated -> Deduct Major Points -> Alert Counselor.
