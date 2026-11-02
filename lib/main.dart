import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:uuid/uuid.dart';

const lime = Color(0xFFB7F34A);
const bg = Color(0xFF0D0F0E);
const panel = Color(0xFF191D1A);
const muted = Color(0xFF929A93);
const uuid = Uuid();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru_RU');
  runApp(const IronlogApp());
}

class IronlogApp extends StatelessWidget {
  const IronlogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IRONLOG',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ru', 'RU'),
      supportedLocales: const [Locale('ru', 'RU')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bg,
        colorScheme: const ColorScheme.dark(
          primary: lime, secondary: lime, surface: panel,
          onPrimary: Color(0xFF10130C),
        ),
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(backgroundColor: bg, elevation: 0),
        inputDecorationTheme: InputDecorationTheme(
          filled: true, fillColor: panel,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: lime)),
          labelStyle: const TextStyle(color: muted),
        ),
      ),
      home: const HomePage(),
    );
  }
}

class WorkoutSet {
  double weight;
  int reps;
  WorkoutSet({required this.weight, required this.reps});
  Map<String, dynamic> toJson() => {'weight': weight, 'reps': reps};
  factory WorkoutSet.fromJson(Map<String, dynamic> j) =>
      WorkoutSet(weight: (j['weight'] as num).toDouble(), reps: j['reps'] as int);
}

class ExerciseEntry {
  String name;
  List<WorkoutSet> sets;
  ExerciseEntry({required this.name, required this.sets});
  Map<String, dynamic> toJson() => {'name': name, 'sets': sets.map((e) => e.toJson()).toList()};
  factory ExerciseEntry.fromJson(Map<String, dynamic> j) => ExerciseEntry(
    name: j['name'], sets: (j['sets'] as List).map((e) => WorkoutSet.fromJson(Map<String, dynamic>.from(e))).toList());
}

class WorkoutEntry {
  String id;
  DateTime date;
  String title;
  List<ExerciseEntry> exercises;
  WorkoutEntry({required this.id, required this.date, required this.title, required this.exercises});
  Map<String, dynamic> toJson() => {
    'id': id, 'date': date.toIso8601String(), 'title': title,
    'exercises': exercises.map((e) => e.toJson()).toList()
  };
  factory WorkoutEntry.fromJson(Map<String, dynamic> j) => WorkoutEntry(
    id: j['id'], date: DateTime.parse(j['date']), title: j['title'],
    exercises: (j['exercises'] as List).map((e) => ExerciseEntry.fromJson(Map<String, dynamic>.from(e))).toList());
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int tab = 0;
  DateTime focused = DateTime.now();
  DateTime selected = DateTime.now();
  List<WorkoutEntry> workouts = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('ironlog_workouts');
    if (raw != null) {
      try {
        workouts = (jsonDecode(raw) as List)
            .map((e) => WorkoutEntry.fromJson(Map<String, dynamic>.from(e))).toList();
      } catch (_) { workouts = []; }
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ironlog_workouts', jsonEncode(workouts.map((e) => e.toJson()).toList()));
  }

  List<WorkoutEntry> get selectedWorkouts => workouts.where((w) => isSameDay(w.date, selected)).toList();
  List<WorkoutEntry> get sortedWorkouts => [...workouts]..sort((a,b) => b.date.compareTo(a.date));

  Future<void> _addWorkout() async {
    final result = await showModalBottomSheet<WorkoutEntry>(
      context: context, isScrollControlled: true, backgroundColor: panel,
      builder: (_) => WorkoutEditor(date: selected));
    if (result != null) {
      setState(() => workouts.add(result));
      await _save();
    }
  }

  Future<void> _deleteWorkout(WorkoutEntry w) async {
    setState(() => workouts.removeWhere((x) => x.id == w.id));
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _calendarPage(), _historyPage(), _progressPage(), _profilePage()
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('IRONLOG', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 22)),
        actions: [IconButton(onPressed: () => _showInfo(), icon: const Icon(Icons.info_outline, color: muted))],
      ),
      body: loading ? const Center(child: CircularProgressIndicator(color: lime)) : pages[tab],
      floatingActionButton: tab == 0 ? FloatingActionButton.extended(
        onPressed: _addWorkout, backgroundColor: lime, foregroundColor: bg,
        icon: const Icon(Icons.add), label: const Text('Тренировка', style: TextStyle(fontWeight: FontWeight.bold)),
      ) : null,
      bottomNavigationBar: NavigationBar(
        backgroundColor: panel, indicatorColor: lime.withOpacity(.16),
        selectedIndex: tab, onDestinationSelected: (v) => setState(() => tab = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'Календарь'),
          NavigationDestination(icon: Icon(Icons.history), label: 'История'),
          NavigationDestination(icon: Icon(Icons.show_chart), label: 'Прогресс'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Профиль'),
        ],
      ),
    );
  }

  Widget _calendarPage() {
    final month = DateFormat('LLLL yyyy', 'ru').format(focused);
    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 100), children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(month.toUpperCase(), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1)),
        Row(children: [
          _roundIcon(Icons.chevron_left, () => setState(() => focused = DateTime(focused.year, focused.month - 1))),
          const SizedBox(width: 8),
          _roundIcon(Icons.chevron_right, () => setState(() => focused = DateTime(focused.year, focused.month + 1))),
        ])
      ]),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(20)),
        child: TableCalendar<WorkoutEntry>(
          locale: 'ru_RU', firstDay: DateTime.utc(2020), lastDay: DateTime.utc(2035),
          focusedDay: focused, selectedDayPredicate: (d) => isSameDay(d, selected),
          calendarFormat: CalendarFormat.month, availableCalendarFormats: const {CalendarFormat.month: 'Месяц'},
          eventLoader: (day) => workouts.where((w) => isSameDay(w.date, day)).toList(),
          onDaySelected: (s, f) => setState(() { selected = s; focused = f; }),
          onPageChanged: (f) => setState(() => focused = f),
          headerVisible: false, daysOfWeekStyle: const DaysOfWeekStyle(
            weekdayStyle: TextStyle(color: muted, fontSize: 11), weekendStyle: TextStyle(color: muted, fontSize: 11)),
          calendarStyle: CalendarStyle(
            outsideDaysVisible: false, defaultTextStyle: const TextStyle(color: Colors.white),
            weekendTextStyle: const TextStyle(color: Colors.white),
            todayDecoration: BoxDecoration(border: Border.all(color: lime), shape: BoxShape.circle),
            selectedDecoration: const BoxDecoration(color: lime, shape: BoxShape.circle),
            selectedTextStyle: const TextStyle(color: bg, fontWeight: FontWeight.bold),
            markerDecoration: const BoxDecoration(color: lime, shape: BoxShape.circle),
            markersMaxCount: 1, markerSize: 5, cellMargin: const EdgeInsets.all(5)),
        ),
      ),
      const SizedBox(height: 22),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(DateFormat('d MMMM', 'ru').format(selected), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
        Text('${selectedWorkouts.length} тренировок', style: const TextStyle(color: muted, fontSize: 12)),
      ]),
      const SizedBox(height: 12),
      if (selectedWorkouts.isEmpty)
        _emptyCard('В этот день тренировок нет', 'Нажми «Тренировка», чтобы добавить занятие.')
      else ...selectedWorkouts.map((w) => _workoutCard(w, onDelete: () => _deleteWorkout(w))),
    ]);
  }

  Widget _historyPage() => ListView(padding: const EdgeInsets.all(16), children: [
    const Text('ИСТОРИЯ', style: TextStyle(color: muted, letterSpacing: 1.5, fontSize: 12)),
    const SizedBox(height: 14),
    if (sortedWorkouts.isEmpty) _emptyCard('Пока пусто', 'Добавленные тренировки появятся здесь.')
    else ...sortedWorkouts.map((w) => _workoutCard(w, onDelete: () => _deleteWorkout(w))),
  ]);

  Widget _progressPage() {
    final totalSets = workouts.fold<int>(0, (s,w) => s + w.exercises.fold<int>(0, (a,e) => a + e.sets.length));
    final totalVolume = workouts.fold<double>(0, (s,w) => s + w.exercises.fold<double>(0, (a,e) => a + e.sets.fold<double>(0, (b,x) => b + x.weight*x.reps)));
    final weekly = List.generate(7, (i) {
      final day = DateTime.now().subtract(Duration(days: 6-i));
      return workouts.where((w) => isSameDay(w.date, day)).length.toDouble();
    });
    return ListView(padding: const EdgeInsets.all(16), children: [
      const Text('ТВОЙ ПРОГРЕСС', style: TextStyle(color: muted, letterSpacing: 1.5, fontSize: 12)),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: _statCard('ТРЕНИРОВКИ', '${workouts.length}', Icons.fitness_center)),
        const SizedBox(width: 10),
        Expanded(child: _statCard('ПОДХОДЫ', '$totalSets', Icons.repeat)),
      ]),
      const SizedBox(height: 10),
      _statCard('ОБЪЁМ РАБОТЫ', '${totalVolume.toStringAsFixed(0)} кг × повт.', Icons.bolt),
      const SizedBox(height: 22),
      const Text('АКТИВНОСТЬ ЗА 7 ДНЕЙ', style: TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      Container(height: 190, padding: const EdgeInsets.fromLTRB(12, 20, 20, 8),
        decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(18)),
        child: BarChart(BarChartData(
          borderData: FlBorderData(show: false), gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v,m) {
              final d = DateTime.now().subtract(Duration(days: 6-v.toInt()));
              return Padding(padding: const EdgeInsets.only(top: 8), child: Text(DateFormat('E','ru').format(d), style: const TextStyle(color: muted, fontSize: 10)));
            })),
          ),
          barGroups: List.generate(7, (i) => BarChartGroupData(x: i, barRods: [
            BarChartRodData(toY: weekly[i], color: lime, width: 14, borderRadius: BorderRadius.circular(5))
          ])),
        )),
      ),
      const SizedBox(height: 12),
      const Text('Совет: записывай каждый подход — так IRONLOG сможет точнее показывать рост рабочих весов.', style: TextStyle(color: muted, height: 1.5)),
    ]);
  }

  Widget _profilePage() => ListView(padding: const EdgeInsets.all(16), children: [
    const SizedBox(height: 12),
    const CircleAvatar(radius: 38, backgroundColor: panel, child: Icon(Icons.person, color: lime, size: 38)),
    const SizedBox(height: 14),
    const Center(child: Text('ТВОЙ ПРОФИЛЬ', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5))),
    const SizedBox(height: 24),
    _profileTile(Icons.cloud_sync_outlined, 'Облачная синхронизация', 'Будет подключена после настройки Supabase'),
    _profileTile(Icons.lock_outline, 'Аккаунт', 'Email, Google и Apple'),
    _profileTile(Icons.storage_outlined, 'Хранение данных', 'Локально на этом устройстве'),
    _profileTile(Icons.info_outline, 'О приложении', 'IRONLOG · версия 1.0.0'),
    const SizedBox(height: 12),
    const Text('Сейчас это первая локальная версия. Не удаляй приложение, если в нём есть важные записи: резервная копия пока не подключена.', style: TextStyle(color: muted, fontSize: 12, height: 1.5)),
  ]);

  Widget _profileTile(IconData icon, String title, String subtitle) => Container(
    margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(16)),
    child: Row(children: [Icon(icon, color: lime), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 4),
      Text(subtitle, style: const TextStyle(color: muted, fontSize: 12))
    ]))]),
  );

  Widget _roundIcon(IconData icon, VoidCallback onTap) => InkWell(
    onTap: onTap, borderRadius: BorderRadius.circular(30),
    child: Container(width: 34, height: 34, decoration: const BoxDecoration(color: panel, shape: BoxShape.circle),
      child: Icon(icon, color: lime, size: 20)),
  );

  Widget _emptyCard(String title, String subtitle) => Container(
    padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(18)),
    child: Column(children: [const Icon(Icons.event_available, color: lime, size: 30), const SizedBox(height: 10),
      Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 5),
      Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: muted, fontSize: 12))]),
  );

  Widget _statCard(String label, String value, IconData icon) => Container(
    padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(16)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: lime), const SizedBox(height: 12),
      Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
      const SizedBox(height: 4), Text(label, style: const TextStyle(color: muted, fontSize: 10, letterSpacing: .8)),
    ]),
  );

  Widget _workoutCard(WorkoutEntry w, {required VoidCallback onDelete}) => Container(
    margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(16)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Expanded(child: Text(w.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline, color: muted, size: 20))]),
      Text(DateFormat('d MMM yyyy', 'ru').format(w.date), style: const TextStyle(color: muted, fontSize: 11)),
      const SizedBox(height: 10),
      ...w.exercises.map((e) => Padding(padding: const EdgeInsets.only(bottom: 7), child: Row(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.fitness_center, color: lime, size: 15), const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(e.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(e.sets.asMap().entries.map((x) => '${x.key+1}: ${x.value.weight} кг × ${x.value.reps}').join('   •   '),
              style: const TextStyle(color: muted, fontSize: 11)),
          ]))
        ]))),
    ]),
  );

  void _showInfo() => showAboutDialog(context: context, applicationName: 'IRONLOG',
    applicationVersion: '1.0.0', applicationLegalese: 'Твой прогресс. Твои правила.');
}

class WorkoutEditor extends StatefulWidget {
  final DateTime date;
  const WorkoutEditor({super.key, required this.date});
  @override
  State<WorkoutEditor> createState() => _WorkoutEditorState();
}

class _WorkoutEditorState extends State<WorkoutEditor> {
  final title = TextEditingController(text: 'Тренировка');
  final exercises = <_ExerciseDraft>[];
  final commonExercises = ['Жим лёжа', 'Тяга верхнего блока', 'Горизонтальная тяга', 'Приседания', 'Жим гантелей', 'Подъём на бицепс', 'Разведения в стороны', 'Румынская тяга'];

  @override
  void initState() { super.initState(); _addExercise('Жим лёжа'); }
  @override
  void dispose() { title.dispose(); for (final e in exercises) { e.dispose(); } super.dispose(); }

  void _addExercise([String? name]) => setState(() => exercises.add(_ExerciseDraft(name ?? 'Новое упражнение')));
  void _removeExercise(int i) => setState(() { exercises[i].dispose(); exercises.removeAt(i); });

  void _finish() {
    final valid = exercises.where((e) => e.name.text.trim().isNotEmpty && e.sets.isNotEmpty).toList();
    if (valid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Добавь хотя бы одно упражнение с подходом')));
      return;
    }
    Navigator.pop(context, WorkoutEntry(
      id: uuid.v4(), date: widget.date, title: title.text.trim().isEmpty ? 'Тренировка' : title.text.trim(),
      exercises: valid.map((e) => ExerciseEntry(name: e.name.text.trim(), sets: e.sets.map((s) => WorkoutSet(
        weight: double.tryParse(s.weight.text.replaceAll(',', '.')) ?? 0,
        reps: int.tryParse(s.reps.text) ?? 0)).toList())).toList(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(child: Padding(
      padding: EdgeInsets.only(left: 18, right: 18, top: 18, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: SizedBox(height: MediaQuery.of(context).size.height * .85, child: Column(children: [
        Row(children: [const Expanded(child: Text('НОВАЯ ТРЕНИРОВКА', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2))),
          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close))]),
        Align(alignment: Alignment.centerLeft, child: Text(DateFormat('d MMMM yyyy', 'ru').format(widget.date), style: const TextStyle(color: muted))),
        const SizedBox(height: 14),
        TextField(controller: title, decoration: const InputDecoration(labelText: 'Название тренировки', prefixIcon: Icon(Icons.edit_outlined))),
        const SizedBox(height: 12),
        Expanded(child: ListView(children: [
          ...List.generate(exercises.length, (i) => _exerciseCard(i)),
          const SizedBox(height: 8),
          OutlinedButton.icon(onPressed: () async {
            final picked = await showModalBottomSheet<String>(context: context, backgroundColor: panel, builder: (ctx) => SafeArea(child: ListView(
              shrinkWrap: true, children: [
                const Padding(padding: EdgeInsets.all(16), child: Text('ВЫБЕРИ УПРАЖНЕНИЕ', style: TextStyle(fontWeight: FontWeight.bold))),
                ...commonExercises.map((n) => ListTile(title: Text(n), onTap: () => Navigator.pop(ctx, n))),
                ListTile(leading: const Icon(Icons.edit), title: const Text('Своё упражнение'), onTap: () => Navigator.pop(ctx, 'Новое упражнение'))
              ])));
            if (picked != null) _addExercise(picked);
          }, icon: const Icon(Icons.add), label: const Text('Добавить упражнение'), style: OutlinedButton.styleFrom(foregroundColor: lime, side: const BorderSide(color: lime))),
        ])),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, child: FilledButton(
          onPressed: _finish, style: FilledButton.styleFrom(backgroundColor: lime, foregroundColor: bg, padding: const EdgeInsets.all(16)),
          child: const Text('СОХРАНИТЬ ТРЕНИРОВКУ', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: .5)))),
      ])),
    ));
  }

  Widget _exerciseCard(int i) {
    final e = exercises[i];
    return Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white10)),
      child: Column(children: [
        Row(children: [Expanded(child: TextField(controller: e.name, decoration: const InputDecoration(labelText: 'Упражнение'))),
          IconButton(onPressed: () => _removeExercise(i), icon: const Icon(Icons.delete_outline, color: muted))]),
        const SizedBox(height: 10),
        const Row(children: [SizedBox(width: 34), Expanded(child: Text('ВЕС, КГ', style: TextStyle(color: muted, fontSize: 10))),
          SizedBox(width: 10), Expanded(child: Text('ПОВТОРЕНИЯ', style: TextStyle(color: muted, fontSize: 10))), SizedBox(width: 36)]),
        ...List.generate(e.sets.length, (j) => Padding(padding: const EdgeInsets.only(top: 7), child: Row(children: [
          SizedBox(width: 34, child: Text('${j+1}', style: const TextStyle(color: lime, fontWeight: FontWeight.bold))),
          Expanded(child: TextField(controller: e.sets[j].weight, keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(hintText: '0', contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)))),
          const SizedBox(width: 10),
          Expanded(child: TextField(controller: e.sets[j].reps, keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: '0', contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)))),
          IconButton(onPressed: () => setState(() { e.sets[j].dispose(); e.sets.removeAt(j); }), icon: const Icon(Icons.remove_circle_outline, color: muted, size: 19)),
        ]))),
        Align(alignment: Alignment.centerLeft, child: TextButton.icon(
          onPressed: () => setState(() => e.sets.add(_SetDraft())), icon: const Icon(Icons.add, size: 16),
          label: const Text('Добавить подход'), style: TextButton.styleFrom(foregroundColor: lime))),
      ]),
    );
  }
}

class _ExerciseDraft {
  final TextEditingController name;
  final List<_SetDraft> sets = [];
  _ExerciseDraft(String value) : name = TextEditingController(text: value) { sets.add(_SetDraft()); sets.add(_SetDraft()); sets.add(_SetDraft()); }
  void dispose() { name.dispose(); for (final s in sets) { s.dispose(); } }
}
class _SetDraft {
  final weight = TextEditingController();
  final reps = TextEditingController();
  void dispose() { weight.dispose(); reps.dispose(); }
}
