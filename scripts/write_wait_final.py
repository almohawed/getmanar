import pathlib

# Write completely new wait management screen using StreamBuilder for teachers
dart = """library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth/presentation/auth_controller.dart';

const _wColors = [Color(0xFF4F46E5),Color(0xFF059669),Color(0xFFD97706),Color(0xFFDC2626)];

class _Slot {
  final String day; final int period;
  List<String> teacherIds; List<String> teacherNames; bool isManual;
  _Slot({required this.day,required this.period,required this.teacherIds,required this.teacherNames,this.isManual=false});
  Map<String,dynamic> toMap()=>{'day':day,'period':period,'teacherIds':teacherIds,'teacherNames':teacherNames,'isManual':isManual};
}

class WaitManagementScreen extends ConsumerStatefulWidget {
  const WaitManagementScreen({super.key});
  @override ConsumerState<WaitManagementScreen> createState()=>_State();
}

class _State extends ConsumerState<WaitManagementScreen> {
  Map<String,Map<int,_Slot>> _schedule={};
  bool _isSaving=false; int _waitCount=2;
  final _days=['الاحد','الاثنين','الثلاثاء','الاربعاء','الخميس'];
  final _periods=7;

  String? get _sid => ref.read(authStateProvider).value?.schoolId;

  void _generate(List<Map<String,dynamic>> teachers) {
    if(teachers.isEmpty)return;
    _schedule={};
    final cnt=<String,int>{};
    for(final t in teachers)cnt[t['id'] as String]=0;
    final sorted=List<Map<String,dynamic>>.from(teachers)
      ..sort((a,b)=>(b['max'] as int).compareTo(a['max'] as int));
    for(final day in _days){
      _schedule[day]={};
      for(int p=1;p<=_periods;p++){
        final used=<String>{};
        for(final s in _schedule[day]!.values)used.addAll(s.teacherIds);
        final ids=<String>[]; final names=<String>[];
        for(int pos=0;pos<_waitCount;pos++){
          Map<String,dynamic>? ch; int mn=9999;
          for(final t in sorted){
            final id=t['id'] as String;
            if(ids.contains(id))continue;
            if(pos==0&&used.contains(id))continue;
            final c2=cnt[id]??0;
            if(c2<mn){mn=c2;ch=t;}
          }
          if(ch==null){for(final t in sorted){final id=t['id'] as String;if(ids.contains(id))continue;final c2=cnt[id]??0;if(c2<mn){mn=c2;ch=t;}}}
          if(ch!=null){final id=ch['id'] as String;ids.add(id);names.add(ch['name'] as String);cnt[id]=(cnt[id]??0)+1;}
        }
        if(ids.isNotEmpty)_schedule[day]![p]=_Slot(day:day,period:p,teacherIds:ids,teacherNames:names);
      }
    }
    setState((){});
  }

  Future<void> _importFromSchedule(List<Map<String,dynamic>> teachers) async {
    final sid=_sid; if(sid==null)return;
    try{
      final snap=await FirebaseFirestore.instance.collection('Schools').doc(sid).collection('TeacherSchedules').get();
      final nameById=<String,String>{for(final t in teachers)t['id'] as String:t['name'] as String};
      final wm=<String,Map<int,Map<int,Map<String,String>>>>{};
      for(final doc in snap.docs){
        final tid=doc.id; final tname=nameById[tid]??'';
        final slots=(doc.data()['slots'] as List?)??[];
        for(final slot in slots){
          if(slot is! Map)continue;
          final subj=(slot['subject']??'').toString();
          final day=(slot['day']??slot['dayName']??'').toString();
          final per=(slot['period'] as num?)?.toInt()??0;
          if(!subj.contains('منتظر')&&!subj.contains('انتظار')&&!subj.contains('نوبة'))continue;
          if(day.isEmpty||per==0)continue;
          int wn=1; final nm=RegExp(r'(\\d+)').firstMatch(subj);
          if(nm!=null)wn=int.tryParse(nm.group(1)!)??1;
          wm.putIfAbsent(day,()=>{});
          wm[day]!.putIfAbsent(per,()=>{});
          wm[day]![per]![wn]={'id':tid,'name':tname};
        }
      }
      if(wm.isEmpty){_generate(teachers);if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('لا توجد حصص انتظار - تم التوليد التلقائي'),backgroundColor:Color(0xFFD97706),behavior:SnackBarBehavior.floating));return;}
      _schedule={};
      for(final day in wm.keys){
        _schedule[day]={};
        for(final per in wm[day]!.keys){
          final byN=wm[day]![per]!;
          final ids=<String>[]; final names=<String>[];
          for(int i=1;i<=_waitCount;i++){if(byN.containsKey(i)){ids.add(byN[i]!['id']!);names.add(byN[i]!['name']!);}}
          if(ids.isNotEmpty)_schedule[day]![per]=_Slot(day:day,period:per,teacherIds:ids,teacherNames:names);
        }
      }
      if(mounted){setState((){});ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تم استيراد جدول الانتظار'),backgroundColor:const Color(0xFF059669),behavior:SnackBarBehavior.floating));}
    }catch(e){_generate(teachers);}
  }

  Future<void> _save() async {
    final sid=_sid; if(sid==null)return;
    setState(()=>_isSaving=true);
    try{
      final slots=<Map<String,dynamic>>[];
      for(final d in _schedule.keys)for(final s in _schedule[d]!.values)slots.add(s.toMap());
      await FirebaseFirestore.instance.collection('Schools').doc(sid).collection('WaitSchedule').doc('current')
          .set({'slots':slots,'waitCount':_waitCount,'updatedAt':FieldValue.serverTimestamp()});
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('تم الحفظ'),backgroundColor:Color(0xFF059669),behavior:SnackBarBehavior.floating));
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('خطأ: \$e'),backgroundColor:Colors.red));}
    finally{if(mounted)setState(()=>_isSaving=false);}
  }

  void _edit(String day,int period,List<Map<String,dynamic>> teachers){
    final slot=_schedule[day]?[period];
    final sel=List<String?>.filled(_waitCount,null);
    if(slot!=null)for(int i=0;i<slot.teacherIds.length&&i<_waitCount;i++)sel[i]=slot.teacherIds[i];
    showDialog(context:context,builder:(_)=>AlertDialog(
      backgroundColor:Colors.white,
      shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16)),
      title:Text('تعديل: \$day - الحصة \$period',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:15)),
      content:StatefulBuilder(builder:(ctx,setS)=>SizedBox(width:340,child:Column(mainAxisSize:MainAxisSize.min,children:[
        ...List.generate(_waitCount,(i)=>Padding(padding:const EdgeInsets.only(bottom:10),child:DropdownButtonFormField<String>(
          value:sel[i],
          decoration:InputDecoration(labelText:'منتظر \${i+1}',labelStyle:TextStyle(color:_wColors[i%_wColors.length]),
            border:OutlineInputBorder(borderRadius:BorderRadius.circular(10)),
            enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(10),borderSide:BorderSide(color:_wColors[i%_wColors.length].withOpacity(0.4))),
            filled:true,fillColor:_wColors[i%_wColors.length].withOpacity(0.04)),
          items:[const DropdownMenuItem<String>(value:null,child:Text('-- فارغ --')),
            ...teachers.map((t)=>DropdownMenuItem(value:t['id'] as String,child:Text(t['name'] as String,style:const TextStyle(fontSize:13))))],
          onChanged:(v)=>setS(()=>sel[i]=v),
        ))),
      ]))),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(context),child:const Text('إلغاء',style:TextStyle(color:Colors.grey))),
        ElevatedButton(onPressed:(){
          Navigator.pop(context);
          setState((){
            final ids=sel.where((s)=>s!=null).cast<String>().toList();
            final names=ids.map((id){final t=teachers.firstWhere((t)=>t['id']==id,orElse:()=>{'name':''});return t['name'] as String;}).toList();
            if(ids.isEmpty){_schedule[day]?.remove(period);}
            else{_schedule.putIfAbsent(day,()=>{});_schedule[day]![period]=_Slot(day:day,period:period,teacherIds:ids,teacherNames:names,isManual:true);}
          });
        },style:ElevatedButton.styleFrom(backgroundColor:const Color(0xFF4F46E5),foregroundColor:Colors.white,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(10))),child:const Text('حفظ')),
      ],
    ));
  }

  @override
  Widget build(BuildContext context){
    final sid=ref.watch(authStateProvider).value?.schoolId??'';
    return Scaffold(
      backgroundColor:const Color(0xFFF8FAFF),
      body:sid.isEmpty?const Center(child:CircularProgressIndicator()):StreamBuilder<QuerySnapshot>(
        stream:FirebaseFirestore.instance.collection('Schools').doc(sid).collection('Teachers').snapshots(),
        builder:(ctx,snap){
          final teachers=snap.hasData?snap.data!.docs.map((d){final data=d.data() as Map<String,dynamic>;return {'id':d.id,'name':(data['name']??'').toString(),'max':(data['maxWeeklyClasses']??24) as int};}).where((t)=>(t['name'] as String).isNotEmpty).toList():[];
          return Column(children:[
            _topBar(teachers),
            Expanded(child:SingleChildScrollView(padding:const EdgeInsets.all(16),child:Column(children:[_legend(),const SizedBox(height:12),_grid(teachers),const SizedBox(height:40)]))),
          ]);
        },
      ),
    );
  }

  Widget _topBar(List<Map<String,dynamic>> teachers){
    return Container(
      padding:const EdgeInsets.fromLTRB(16,48,16,12),
      decoration:BoxDecoration(color:Colors.white,border:const Border(bottom:BorderSide(color:Color(0xFFE2E8F0))),
        boxShadow:[BoxShadow(color:Colors.black.withOpacity(0.04),blurRadius:8,offset:const Offset(0,2))]),
      child:Column(children:[
        Row(children:[
          GestureDetector(onTap:()=>Navigator.of(context).pop(),child:Container(width:36,height:36,decoration:BoxDecoration(color:const Color(0xFFF8FAFF),borderRadius:BorderRadius.circular(10),border:Border.all(color:const Color(0xFFE2E8F0))),child:const Icon(Icons.arrow_back_ios_new_rounded,color:Color(0xFF64748B),size:15))),
          const SizedBox(width:12),
          Container(width:40,height:40,decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xFF4F46E5),Color(0xFF06B6D4)],begin:Alignment.topLeft,end:Alignment.bottomRight),borderRadius:BorderRadius.circular(12),boxShadow:[BoxShadow(color:const Color(0xFF4F46E5).withOpacity(0.3),blurRadius:10,offset:const Offset(0,4))]),child:const Icon(Icons.hourglass_top_rounded,color:Colors.white,size:20)),
          const SizedBox(width:10),
          const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text('جدول الانتظار',style:TextStyle(color:Color(0xFF1E293B),fontSize:16,fontWeight:FontWeight.bold)),
            Text('توزيع ذكي حسب النصاب',style:TextStyle(color:Color(0xFF64748B),fontSize:11)),
          ])),
          Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:6),decoration:BoxDecoration(color:const Color(0xFFF8FAFF),borderRadius:BorderRadius.circular(10),border:Border.all(color:const Color(0xFFE2E8F0))),
            child:Row(mainAxisSize:MainAxisSize.min,children:[
              const Text('منتظرين:',style:TextStyle(color:Color(0xFF64748B),fontSize:11)),const SizedBox(width:6),
              ...List.generate(4,(i)=>GestureDetector(onTap:()=>setState((){_waitCount=i+1;_generate(teachers);}),child:Container(width:28,height:28,margin:const EdgeInsets.only(left:4),decoration:BoxDecoration(color:_waitCount==i+1?_wColors[i]:_wColors[i].withOpacity(0.1),borderRadius:BorderRadius.circular(8),border:Border.all(color:_wColors[i].withOpacity(0.4))),child:Center(child:Text('\${i+1}',style:TextStyle(color:_waitCount==i+1?Colors.white:_wColors[i],fontSize:12,fontWeight:FontWeight.bold)))))),
            ])),
        ]),
        const SizedBox(height:10),
        Row(children:[
          OutlinedButton.icon(onPressed:()=>_importFromSchedule(teachers),icon:const Icon(Icons.download_rounded,size:14,color:Color(0xFF4F46E5)),label:const Text('استيراد من الجدول',style:TextStyle(fontSize:12,color:Color(0xFF4F46E5))),style:OutlinedButton.styleFrom(side:const BorderSide(color:Color(0xFF4F46E5),),padding:const EdgeInsets.symmetric(horizontal:12,vertical:8),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(10)))),
          const SizedBox(width:8),
          OutlinedButton.icon(onPressed:()=>setState(()=>_generate(teachers)),icon:const Icon(Icons.auto_fix_high_rounded,size:14,color:Color(0xFF059669)),label:const Text('توزيع تلقائي',style:TextStyle(fontSize:12,color:Color(0xFF059669))),style:OutlinedButton.styleFrom(side:const BorderSide(color:Color(0xFF059669)),padding:const EdgeInsets.symmetric(horizontal:12,vertical:8),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(10)))),
          const Spacer(),
          ElevatedButton.icon(onPressed:_isSaving?null:_save,icon:_isSaving?const SizedBox(width:14,height:14,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)):const Icon(Icons.save_rounded,size:15),label:const Text('حفظ',style:TextStyle(fontSize:13,fontWeight:FontWeight.bold)),style:ElevatedButton.styleFrom(backgroundColor:const Color(0xFF059669),foregroundColor:Colors.white,padding:const EdgeInsets.symmetric(horizontal:20,vertical:10),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(10)),elevation:0)),
        ]),
      ]),
    );
  }

  Widget _legend(){
    return Container(padding:const EdgeInsets.symmetric(horizontal:16,vertical:10),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(12),border:Border.all(color:const Color(0xFFE2E8F0))),
      child:Row(children:[const Text('دليل الألوان:',style:TextStyle(color:Color(0xFF64748B),fontSize:12,fontWeight:FontWeight.bold)),const SizedBox(width:12),
        ...List.generate(_waitCount,(i)=>Container(margin:const EdgeInsets.only(left:10),padding:const EdgeInsets.symmetric(horizontal:10,vertical:4),decoration:BoxDecoration(color:_wColors[i%_wColors.length].withOpacity(0.1),borderRadius:BorderRadius.circular(20),border:Border.all(color:_wColors[i%_wColors.length].withOpacity(0.3))),
          child:Row(mainAxisSize:MainAxisSize.min,children:[Container(width:8,height:8,decoration:BoxDecoration(color:_wColors[i%_wColors.length],shape:BoxShape.circle)),const SizedBox(width:5),Text('منتظر \${i+1}',style:TextStyle(color:_wColors[i%_wColors.length],fontSize:11,fontWeight:FontWeight.w600))]))),
      ]));
  }

  Widget _grid(List<Map<String,dynamic>> teachers){
    final dc=[const Color(0xFF4F46E5),const Color(0xFF059669),const Color(0xFFD97706),const Color(0xFFDC2626),const Color(0xFF7C3AED)];
    return Container(decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(16),border:Border.all(color:const Color(0xFFE2E8F0)),boxShadow:[BoxShadow(color:Colors.black.withOpacity(0.04),blurRadius:12)]),
      child:Column(children:[
        Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:10),decoration:const BoxDecoration(color:Color(0xFFF8FAFF),borderRadius:BorderRadius.vertical(top:Radius.circular(16)),border:Border(bottom:BorderSide(color:Color(0xFFE2E8F0)))),
          child:Row(children:[const SizedBox(width:52,child:Text('الحصة',style:TextStyle(color:Color(0xFF64748B),fontSize:11,fontWeight:FontWeight.bold),textAlign:TextAlign.center)),
            ...List.generate(_days.length,(i)=>Expanded(child:Center(child:Container(padding:const EdgeInsets.symmetric(horizontal:6,vertical:4),decoration:BoxDecoration(color:dc[i].withOpacity(0.1),borderRadius:BorderRadius.circular(8)),child:Text(_days[i],style:TextStyle(color:dc[i],fontSize:11,fontWeight:FontWeight.bold)))))),
          ])),
        ...List.generate(_periods,(pi){
          final p=pi+1;
          return Container(decoration:BoxDecoration(color:pi%2==0?Colors.white:const Color(0xFFFAFBFF),border:const Border(bottom:BorderSide(color:Color(0xFFE2E8F0),width:0.5))),
            child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Container(width:52,padding:const EdgeInsets.symmetric(vertical:8),decoration:const BoxDecoration(color:Color(0xFFF1F5F9),border:Border(right:BorderSide(color:Color(0xFFE2E8F0),width:0.5))),
                child:Center(child:Column(mainAxisSize:MainAxisSize.min,children:[Text('\$p',style:const TextStyle(color:Color(0xFF4F46E5),fontSize:16,fontWeight:FontWeight.bold)),const Text('حصة',style:TextStyle(color:Color(0xFF94A3B8),fontSize:9))]))),
              ...List.generate(_days.length,(di){
                final day=_days[di]; final slot=_schedule[day]?[p];
                return Expanded(child:GestureDetector(onTap:()=>_edit(day,p,teachers),child:Container(margin:const EdgeInsets.all(3),padding:const EdgeInsets.all(4),decoration:BoxDecoration(color:slot!=null?const Color(0xFFF8FAFF):const Color(0xFFF1F5F9),borderRadius:BorderRadius.circular(8),border:Border.all(color:slot!=null?const Color(0xFFCBD5E1):const Color(0xFFE2E8F0))),
                  child:slot!=null?Column(mainAxisSize:MainAxisSize.min,children:[
                    if(slot.isManual)Container(margin:const EdgeInsets.only(bottom:2),padding:const EdgeInsets.symmetric(horizontal:4,vertical:1),decoration:BoxDecoration(color:const Color(0xFFFEF3C7),borderRadius:BorderRadius.circular(4)),child:const Text('يدوي',style:TextStyle(color:Color(0xFFD97706),fontSize:8,fontWeight:FontWeight.bold))),
                    ...List.generate(slot.teacherNames.length,(wi)=>Container(margin:const EdgeInsets.only(bottom:2),padding:const EdgeInsets.symmetric(horizontal:5,vertical:3),decoration:BoxDecoration(color:_wColors[wi%_wColors.length].withOpacity(0.1),borderRadius:BorderRadius.circular(5),border:Border.all(color:_wColors[wi%_wColors.length].withOpacity(0.3))),
                      child:Text(_sn(slot.teacherNames[wi]),style:TextStyle(color:_wColors[wi%_wColors.length],fontSize:9,fontWeight:FontWeight.w600),maxLines:1,overflow:TextOverflow.ellipsis))),
                  ]):const Center(child:Icon(Icons.add_rounded,color:Color(0xFFCBD5E1),size:16)))));
              }),
            ]));
        }),
      ]));
  }

  String _sn(String n){final p=n.trim().split(' ');return p.length>=2?'\${p[0]} \${p[1]}':n;}
}
"""

pathlib.Path("lib/src/features/wait_management/presentation/wait_management_screen.dart").write_text(dart, encoding="utf-8")
print("done")
