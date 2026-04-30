import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CalendarApp());
}

// ─── Event Types ─────────────────────────────────────────────────────────────

enum EventType { trip, meeting, run, birthday, date, school, other }

extension EventTypeExt on EventType {
  String label(bool ru) {
    const ruMap = {
      EventType.trip: 'Поездка', EventType.meeting: 'Встреча',
      EventType.run: 'Пробежка', EventType.birthday: 'День рождения',
      EventType.date: 'Свидание', EventType.school: 'Школа',
      EventType.other: 'Другое',
    };
    const enMap = {
      EventType.trip: 'Trip', EventType.meeting: 'Meeting',
      EventType.run: 'Run', EventType.birthday: 'Birthday',
      EventType.date: 'Date', EventType.school: 'School',
      EventType.other: 'Other',
    };
    return (ru ? ruMap : enMap)[this]!;
  }

  String get emoji => const {
    EventType.trip: '✈️', EventType.meeting: '🤝', EventType.run: '🏃',
    EventType.birthday: '🎂', EventType.date: '❤️', EventType.school: '🎓',
    EventType.other: '📌',
  }[this]!;

  Color get color => const {
    EventType.trip: Color(0xFF5A8FDB), EventType.meeting: Color(0xFF70B8A0),
    EventType.run: Color(0xFFE07B5F), EventType.birthday: Color(0xFFD4A0D0),
    EventType.date: Color(0xFFE87070), EventType.school: Color(0xFFE8C160),
    EventType.other: Color(0xFF9E9E9E),
  }[this]!;
}

// ─── Event Model ─────────────────────────────────────────────────────────────

class CalendarEvent {
  final String id;
  final EventType type;
  final String note;
  final String time; // "HH:mm" or ""

  const CalendarEvent({
    required this.id,
    required this.type,
    this.note = '',
    this.time = '',
  });

  Map<String, dynamic> toJson() =>
      {'id': id, 'type': type.name, 'note': note, 'time': time};

  factory CalendarEvent.fromJson(Map<String, dynamic> j) => CalendarEvent(
    id: j['id'] as String,
    type: EventType.values.firstWhere((e) => e.name == j['type'],
        orElse: () => EventType.other),
    note: j['note'] as String? ?? '',
    time: j['time'] as String? ?? '',
  );

  CalendarEvent copyWith({String? note, String? time}) => CalendarEvent(
      id: id, type: type, note: note ?? this.note, time: time ?? this.time);
}

// ─── App State ───────────────────────────────────────────────────────────────

class AppState extends ChangeNotifier {
  bool _isDark = false;
  bool _isRu = true;
  final Map<String, List<CalendarEvent>> _events = {};

  bool get isDark => _isDark;
  bool get isRu => _isRu;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _isDark = p.getBool('isDark') ?? false;
    _isRu = p.getBool('isRu') ?? true;
    final raw = p.getString('events_v2');
    if (raw != null) {
      final dec = jsonDecode(raw) as Map<String, dynamic>;
      dec.forEach((k, v) {
        _events[k] = (v as List)
            .map((e) => CalendarEvent.fromJson(e as Map<String, dynamic>))
            .toList();
      });
    }
    notifyListeners();
  }

  Future<void> _persist() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
        'events_v2',
        jsonEncode(
            _events.map((k, v) => MapEntry(k, v.map((e) => e.toJson()).toList()))));
  }

  Future<void> toggleTheme() async {
    _isDark = !_isDark;
    (await SharedPreferences.getInstance()).setBool('isDark', _isDark);
    notifyListeners();
  }

  Future<void> toggleLanguage() async {
    _isRu = !_isRu;
    (await SharedPreferences.getInstance()).setBool('isRu', _isRu);
    notifyListeners();
  }

  List<CalendarEvent> getEvents(String key) => _events[key] ?? [];
  bool hasEvents(String key) => (_events[key]?.isNotEmpty) ?? false;

  Future<void> addEvent(String key, CalendarEvent ev) async {
    if ((_events[key]?.length ?? 0) >= 3) return;
    _events[key] = [...(_events[key] ?? []), ev];
    await _persist();
    notifyListeners();
  }

  Future<void> updateEvent(String key, CalendarEvent ev) async {
    final list = _events[key];
    if (list == null) return;
    final i = list.indexWhere((e) => e.id == ev.id);
    if (i != -1) list[i] = ev;
    await _persist();
    notifyListeners();
  }

  Future<void> deleteEvent(String key, String id) async {
    _events[key]?.removeWhere((e) => e.id == id);
    if (_events[key]?.isEmpty ?? false) _events.remove(key);
    await _persist();
    notifyListeners();
  }
}

// ─── Root ────────────────────────────────────────────────────────────────────

class CalendarApp extends StatefulWidget {
  const CalendarApp({super.key});
  @override
  State<CalendarApp> createState() => _CalendarAppState();
}

class _CalendarAppState extends State<CalendarApp> {
  final AppState _st = AppState();
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _st.load().then((_) => setState(() => _ready = true));
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const MaterialApp(
          home: Scaffold(body: Center(child: CircularProgressIndicator())));
    }
    return AnimatedBuilder(
      animation: _st,
      builder: (_, __) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: _st.isDark ? _dark() : _light(),
        home: CalendarHome(st: _st),
      ),
    );
  }

  ThemeData _light() => ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF2F4F8),
      colorScheme:
      const ColorScheme.light(primary: Color(0xFF5A8FDB), surface: Colors.white));

  ThemeData _dark() => ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF1A1D2E),
      colorScheme: const ColorScheme.dark(
          primary: Color(0xFF5A8FDB), surface: Color(0xFF252840)));
}

// ─── Home ────────────────────────────────────────────────────────────────────

class CalendarHome extends StatefulWidget {
  final AppState st;
  const CalendarHome({super.key, required this.st});
  @override
  State<CalendarHome> createState() => _CalendarHomeState();
}

class _CalendarHomeState extends State<CalendarHome> {
  late DateTime _month;
  late DateTime _sel;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _month = DateTime(n.year, n.month);
    _sel = n;
  }

  AppState get s => widget.st;

  static String dk(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String get _monthLabel {
    const ru = ['Январь','Февраль','Март','Апрель','Май','Июнь',
      'Июль','Август','Сентябрь','Октябрь','Ноябрь','Декабрь'];
    const en = ['January','February','March','April','May','June',
      'July','August','September','October','November','December'];
    return '${(s.isRu ? ru : en)[_month.month - 1]} ${_month.year}';
  }

  void _openAdd(DateTime day) => _openSheet(
    _EventSheet(day: day, st: s, onChanged: () => setState(() {})),
  );

  void _openEdit(DateTime day, CalendarEvent ev) => _openSheet(
    _EditSheet(
      day: day, event: ev, st: s,
      onSave: (u) async { await s.updateEvent(dk(day), u); setState(() {}); },
      onDelete: () async { await s.deleteEvent(dk(day), ev.id); setState(() {}); },
    ),
  );

  void _openSheet(Widget sheet) => showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => sheet,
  );

  @override
  Widget build(BuildContext context) {
    final dark = s.isDark;
    final bg = dark ? const Color(0xFF1A1D2E) : const Color(0xFFF2F4F8);
    final card = dark ? const Color(0xFF252840) : Colors.white;
    final txt = dark ? Colors.white : const Color(0xFF1A1D2E);
    final sub = const Color(0xFF8890AA);

    return AnimatedBuilder(
      animation: s,
      builder: (_, __) => Scaffold(
        backgroundColor: bg,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              // Title
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(children: [
                  Text(s.isRu ? 'Календарь' : 'Calendar',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: txt)),
                  const Spacer(),
                  _MenuBtn(st: s),
                ]),
              ),

              // Month nav
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(children: [
                  _Arrow(
                    icon: Icons.chevron_left,
                    onTap: () => setState(() =>
                    _month = DateTime(_month.year, _month.month - 1)),
                    dark: dark,
                  ),
                  const SizedBox(width: 12),
                  Text(_monthLabel,
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: txt)),
                  const SizedBox(width: 12),
                  _Arrow(
                    icon: Icons.chevron_right,
                    onTap: () => setState(() =>
                    _month = DateTime(_month.year, _month.month + 1)),
                    dark: dark,
                  ),
                ]),
              ),
              const SizedBox(height: 16),

              // Calendar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: card,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(dark ? 0.3 : 0.06),
                          blurRadius: 20,
                          offset: const Offset(0, 4))
                    ],
                  ),
                  padding: const EdgeInsets.all(16),
                  child: _Grid(
                    month: _month,
                    sel: _sel,
                    st: s,
                    dark: dark,
                    weekLabels: s.isRu
                        ? ['Вс','Пн','Вт','Ср','Чт','Пт','Сб']
                        : ['Su','Mo','Tu','We','Th','Fr','Sa'],
                    onTap: (d) {
                      setState(() => _sel = d);
                      _openAdd(d);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Day summary
              _DayPanel(
                day: _sel,
                st: s,
                card: card,
                txt: txt,
                sub: sub,
                onEdit: (ev) => _openEdit(_sel, ev),
                onDelete: (ev) async {
                  await s.deleteEvent(dk(_sel), ev.id);
                  setState(() {});
                },
                onAdd: () => _openAdd(_sel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Grid ────────────────────────────────────────────────────────────────────

class _Grid extends StatelessWidget {
  final DateTime month, sel;
  final AppState st;
  final bool dark;
  final List<String> weekLabels;
  final void Function(DateTime) onTap;

  const _Grid({
    required this.month, required this.sel, required this.st,
    required this.dark, required this.weekLabels, required this.onTap,
  });

  static String dk(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final last = DateTime(month.year, month.month + 1, 0);
    final off = first.weekday % 7;
    final cells = <DateTime?>[];
    for (int i = 0; i < off; i++) cells.add(null);
    for (int d = 1; d <= last.day; d++) cells.add(DateTime(month.year, month.month, d));
    while (cells.length % 7 != 0) cells.add(null);

    final lc = dark ? const Color(0xFF8890AA) : const Color(0xFF9DA3B4);

    return Column(children: [
      Row(
        children: weekLabels.asMap().entries.map((e) {
          final we = e.key == 0 || e.key == 6;
          return Expanded(
            child: Center(
              child: Text(e.value,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: we ? const Color(0xFFE07070).withOpacity(0.8) : lc)),
            ),
          );
        }).toList(),
      ),
      const SizedBox(height: 8),
      ...List.generate(cells.length ~/ 7, (row) {
        final rowDays = cells.sublist(row * 7, row * 7 + 7);
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: _Row(days: rowDays, sel: sel, st: st, dark: dark, onTap: onTap),
        );
      }),
    ]);
  }
}

class _Row extends StatelessWidget {
  final List<DateTime?> days;
  final DateTime sel;
  final AppState st;
  final bool dark;
  final void Function(DateTime) onTap;

  const _Row({
    required this.days, required this.sel, required this.st,
    required this.dark, required this.onTap,
  });

  static String dk(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final hasEv = days.map((d) => d != null && st.hasEvents(dk(d))).toList();

    // Find consecutive runs ≥ 2
    final Map<int, int> runs = {};
    int i = 0;
    while (i < days.length) {
      if (hasEv[i]) {
        int j = i;
        while (j < days.length && hasEv[j]) j++;
        if (j - i >= 2) for (int k = i; k < j; k++) runs[k] = j - i;
        i = j;
      } else { i++; }
    }

    // Pill start -> length
    final Map<int, int> pills = {};
    int p = 0;
    while (p < days.length) {
      if (runs.containsKey(p) && !pills.containsKey(p)) {
        final len = runs[p]!;
        pills[p] = len;
        p += len;
      } else { p++; }
    }

    return SizedBox(
      height: 48,
      child: Stack(children: [
        // Blue pills
        ...pills.entries.map((e) {
          final start = e.key;
          final len = e.value;
          const blue = Color(0xFF5A8FDB);
          return Positioned.fill(
            child: LayoutBuilder(builder: (_, c) {
              final cw = c.maxWidth / 7;
              return Stack(children: [
                Positioned(
                  left: start * cw + 2,
                  top: 4,
                  width: len * cw - 4,
                  bottom: 4,
                  child: Container(
                    decoration: BoxDecoration(
                      color: blue.withOpacity(0.13),
                      border: Border.all(color: blue.withOpacity(0.35), width: 1.2),
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
              ]);
            }),
          );
        }),

        // Cells
        Row(
          children: List.generate(days.length, (idx) {
            final day = days[idx];
            if (day == null) return const Expanded(child: SizedBox());

            final key = dk(day);
            final evs = st.getEvents(key);
            final isSel = day.year == sel.year && day.month == sel.month && day.day == sel.day;
            final isToday = day.year == DateTime.now().year &&
                day.month == DateTime.now().month && day.day == DateTime.now().day;
            final isWE = day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
            final hasEv = evs.isNotEmpty;
            final inPill = runs.containsKey(idx);

            Color? bg;
            Color textClr;
            FontWeight fw = FontWeight.w500;

            if (isSel && !hasEv) {
              bg = const Color(0xFF5A8FDB);
              textClr = Colors.white;
              fw = FontWeight.w700;
            } else if (isToday && !hasEv) {
              bg = const Color(0xFF5A8FDB).withOpacity(0.15);
              textClr = const Color(0xFF5A8FDB);
              fw = FontWeight.w700;
            } else if (hasEv && !inPill) {
              bg = evs.first.type.color.withOpacity(0.18);
              textClr = evs.first.type.color;
              fw = FontWeight.w700;
            } else if (hasEv && inPill) {
              textClr = const Color(0xFF5A8FDB);
              fw = FontWeight.w700;
            } else if (isWE) {
              textClr = const Color(0xFFE07070);
            } else {
              textClr = dark ? Colors.white70 : const Color(0xFF2D3250);
            }

            return Expanded(
              child: GestureDetector(
                onTap: () => onTap(day),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(bottom: evs.length > 1 ? 6 : 0),
                        child: Text('${day.day}',
                            style: TextStyle(fontSize: 15, fontWeight: fw, color: textClr)),
                      ),
                      if (hasEv && evs.length > 1)
                        Positioned(
                          bottom: 3,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: evs.take(3).map((ev) => Container(
                              width: 4, height: 4,
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              decoration: BoxDecoration(
                                color: inPill
                                    ? const Color(0xFF5A8FDB).withOpacity(0.6)
                                    : ev.type.color.withOpacity(0.7),
                                shape: BoxShape.circle,
                              ),
                            )).toList(),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ]),
    );
  }
}

// ─── Day Panel ───────────────────────────────────────────────────────────────

class _DayPanel extends StatelessWidget {
  final DateTime day;
  final AppState st;
  final Color card, txt, sub;
  final void Function(CalendarEvent) onEdit;
  final void Function(CalendarEvent) onDelete;
  final VoidCallback onAdd;

  const _DayPanel({
    required this.day, required this.st, required this.card,
    required this.txt, required this.sub,
    required this.onEdit, required this.onDelete, required this.onAdd,
  });

  static String dk(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _label(bool ru) {
    const rm = ['','января','февраля','марта','апреля','мая','июня',
      'июля','августа','сентября','октября','ноября','декабря'];
    const em = ['','Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'];
    return ru ? '${day.day} ${rm[day.month]}' : '${em[day.month]} ${day.day}';
  }

  @override
  Widget build(BuildContext context) {
    final evs = st.getEvents(dk(day));
    final ru = st.isRu;
    final canAdd = evs.length < 3;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 2))],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(
                ru ? 'Задачи на ${_label(ru)}' : 'Tasks for ${_label(ru)}',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: txt),
              ),
              const Spacer(),
              if (canAdd)
                GestureDetector(
                  onTap: onAdd,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5A8FDB).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(children: [
                      const Icon(Icons.add, size: 14, color: Color(0xFF5A8FDB)),
                      const SizedBox(width: 3),
                      Text(ru ? 'Добавить' : 'Add',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF5A8FDB))),
                    ]),
                  ),
                ),
            ]),
            const SizedBox(height: 10),
            if (evs.isEmpty)
              Text(
                ru ? 'Нет событий. Нажмите на дату, чтобы добавить.' : 'No events. Tap a date to add.',
                style: TextStyle(fontSize: 13, color: sub),
              )
            else
              ...evs.map((ev) => _Tile(
                event: ev, ru: ru, dark: st.isDark,
                onEdit: () => onEdit(ev),
                onDelete: () => onDelete(ev),
              )),
            if (evs.length >= 3)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  ru ? '⚠️ Максимум 3 события на день' : '⚠️ Max 3 events per day',
                  style: TextStyle(fontSize: 11, color: sub),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final CalendarEvent event;
  final bool ru, dark;
  final VoidCallback onEdit, onDelete;

  const _Tile({required this.event, required this.ru, required this.dark,
    required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final c = event.type.color;
    return Dismissible(
      key: Key(event.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (_) => _ConfirmDelete(event: event, ru: ru, dark: dark),
        ) ?? false;
      },
      onDismissed: (_) => onDelete(),
      child: GestureDetector(
        onTap: onEdit,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: c.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.withOpacity(0.22), width: 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [
            Text(event.type.emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(event.type.label(ru),
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c)),
                    if (event.time.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: c.withOpacity(0.13),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(children: [
                          Icon(Icons.access_time, size: 10, color: c),
                          const SizedBox(width: 3),
                          Text(event.time,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c)),
                        ]),
                      ),
                    ],
                  ]),
                  if (event.note.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(event.note,
                        style: TextStyle(fontSize: 12,
                            color: dark ? Colors.white54 : const Color(0xFF6B7280)),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(children: [
              Icon(Icons.edit_outlined, size: 16, color: c.withOpacity(0.55)),
              const SizedBox(height: 4),
              Icon(Icons.delete_outline, size: 16, color: Colors.red.withOpacity(0.45)),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _ConfirmDelete extends StatelessWidget {
  final CalendarEvent event;
  final bool ru, dark;
  const _ConfirmDelete({required this.event, required this.ru, required this.dark});

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: dark ? const Color(0xFF252840) : Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    title: Text(ru ? 'Удалить?' : 'Delete?',
        style: TextStyle(color: dark ? Colors.white : Colors.black)),
    content: Text('${event.type.emoji} ${event.type.label(ru)}',
        style: TextStyle(color: dark ? Colors.white70 : Colors.black54)),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context, false),
          child: Text(ru ? 'Отмена' : 'Cancel')),
      TextButton(onPressed: () => Navigator.pop(context, true),
          child: Text(ru ? 'Удалить' : 'Delete',
              style: const TextStyle(color: Colors.red))),
    ],
  );
}

// ─── Add Event Sheet ──────────────────────────────────────────────────────────

class _EventSheet extends StatefulWidget {
  final DateTime day;
  final AppState st;
  final VoidCallback onChanged;
  const _EventSheet({required this.day, required this.st, required this.onChanged});
  @override
  State<_EventSheet> createState() => _EventSheetState();
}

class _EventSheetState extends State<_EventSheet> {
  EventType? _type;
  final _noteCtrl = TextEditingController();
  TimeOfDay? _time;

  static String dk(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  AppState get s => widget.st;
  bool get ru => s.isRu;
  bool get dark => s.isDark;

  @override
  void dispose() { _noteCtrl.dispose(); super.dispose(); }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: _time ?? TimeOfDay.now(),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (t != null) setState(() => _time = t);
  }

  String get _timeStr => _time != null
      ? '${_time!.hour.toString().padLeft(2, '0')}:${_time!.minute.toString().padLeft(2, '0')}'
      : '';

  Future<void> _save() async {
    if (_type == null) return;
    await s.addEvent(
      dk(widget.day),
      CalendarEvent(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: _type!,
        note: _noteCtrl.text.trim(),
        time: _timeStr,
      ),
    );
    widget.onChanged();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bg = dark ? const Color(0xFF252840) : Colors.white;
    final txt = dark ? Colors.white : const Color(0xFF1A1D2E);
    final existing = s.getEvents(dk(widget.day));
    final canAdd = existing.length < 3;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _handle(),
            const SizedBox(height: 12),
            Text(ru ? 'Добавить событие' : 'Add Event',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: txt)),
            const SizedBox(height: 16),

            if (!canAdd) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Text(
                  ru ? '⚠️ Максимум 3 события на день' : '⚠️ Max 3 events per day',
                  style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5A8FDB),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                  ),
                  child: Text(ru ? 'Понятно' : 'Got it',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ),
            ] else ...[
              // Type selector
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 3.4,
                children: EventType.values.map((t) {
                  final sel = _type == t;
                  return GestureDetector(
                    onTap: () => setState(() => _type = t),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        color: sel
                            ? t.color.withOpacity(0.18)
                            : (dark ? Colors.white.withOpacity(0.06) : Colors.grey.withOpacity(0.07)),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: sel ? t.color : Colors.transparent, width: 1.5),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(children: [
                        Text(t.emoji, style: const TextStyle(fontSize: 17)),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(t.label(ru),
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                                  color: sel ? t.color : (dark ? Colors.white70 : const Color(0xFF4A4E69))),
                              overflow: TextOverflow.ellipsis),
                        ),
                      ]),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),

              // Time
              GestureDetector(
                onTap: _pickTime,
                child: _timePicker(txt),
              ),
              const SizedBox(height: 10),

              // Note
              TextField(
                controller: _noteCtrl,
                maxLines: 2,
                style: TextStyle(fontSize: 13, color: txt),
                decoration: _inputDec(ru ? 'Заметка — место, детали...' : 'Note — place, details...', dark),
              ),
              const SizedBox(height: 16),

              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                      side: BorderSide(color: Colors.grey.withOpacity(0.3)),
                    ),
                    child: Text(ru ? 'Отмена' : 'Cancel',
                        style: TextStyle(color: txt.withOpacity(0.5))),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _type != null ? _save : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5A8FDB),
                      disabledBackgroundColor: const Color(0xFF5A8FDB).withOpacity(0.3),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                    ),
                    child: Text(ru ? 'Добавить' : 'Add',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _timePicker(Color txt) {
    final hasTime = _time != null;
    const blue = Color(0xFF5A8FDB);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: dark ? Colors.white.withOpacity(0.06) : Colors.grey.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: hasTime ? blue.withOpacity(0.5) : Colors.transparent, width: 1.5),
      ),
      child: Row(children: [
        Icon(Icons.access_time_rounded, size: 18,
            color: hasTime ? blue : (dark ? Colors.white38 : Colors.grey)),
        const SizedBox(width: 10),
        Text(
          hasTime ? _timeStr : (ru ? 'Время (необязательно)' : 'Time (optional)'),
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
              color: hasTime ? blue : (dark ? Colors.white38 : Colors.grey)),
        ),
        const Spacer(),
        if (hasTime)
          GestureDetector(
            onTap: () => setState(() => _time = null),
            child: Icon(Icons.close, size: 16, color: Colors.grey.withOpacity(0.6)),
          ),
      ]),
    );
  }
}

// ─── Edit Event Sheet ─────────────────────────────────────────────────────────

class _EditSheet extends StatefulWidget {
  final DateTime day;
  final CalendarEvent event;
  final AppState st;
  final void Function(CalendarEvent) onSave;
  final VoidCallback onDelete;

  const _EditSheet({required this.day, required this.event, required this.st,
    required this.onSave, required this.onDelete});
  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late TextEditingController _noteCtrl;
  TimeOfDay? _time;

  @override
  void initState() {
    super.initState();
    _noteCtrl = TextEditingController(text: widget.event.note);
    final t = widget.event.time;
    if (t.isNotEmpty) {
      final parts = t.split(':');
      if (parts.length == 2) {
        _time = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
    }
  }

  @override
  void dispose() { _noteCtrl.dispose(); super.dispose(); }

  bool get ru => widget.st.isRu;
  bool get dark => widget.st.isDark;
  Color get c => widget.event.type.color;

  String get _timeStr => _time != null
      ? '${_time!.hour.toString().padLeft(2, '0')}:${_time!.minute.toString().padLeft(2, '0')}'
      : '';

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: _time ?? TimeOfDay.now(),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (t != null) setState(() => _time = t);
  }

  void _save() {
    widget.onSave(widget.event.copyWith(note: _noteCtrl.text.trim(), time: _timeStr));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bg = dark ? const Color(0xFF252840) : Colors.white;
    final txt = dark ? Colors.white : const Color(0xFF1A1D2E);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _handle(),
            const SizedBox(height: 12),
            Row(children: [
              Text(widget.event.type.emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${ru ? 'Редактировать' : 'Edit'}: ${widget.event.type.label(ru)}',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: txt),
                ),
              ),
              IconButton(
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => _ConfirmDelete(event: widget.event, ru: ru, dark: dark),
                  );
                  if (ok == true && mounted) {
                    Navigator.pop(context);
                    widget.onDelete();
                  }
                },
                icon: const Icon(Icons.delete_outline, color: Colors.red),
              ),
            ]),
            const SizedBox(height: 14),

            // Time
            GestureDetector(
              onTap: _pickTime,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: dark ? Colors.white.withOpacity(0.06) : Colors.grey.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _time != null ? c.withOpacity(0.5) : Colors.transparent, width: 1.5),
                ),
                child: Row(children: [
                  Icon(Icons.access_time_rounded, size: 18,
                      color: _time != null ? c : (dark ? Colors.white38 : Colors.grey)),
                  const SizedBox(width: 10),
                  Text(
                    _time != null ? _timeStr : (ru ? 'Выбрать время' : 'Pick time'),
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                        color: _time != null ? c : (dark ? Colors.white38 : Colors.grey)),
                  ),
                  const Spacer(),
                  if (_time != null)
                    GestureDetector(
                      onTap: () => setState(() => _time = null),
                      child: Icon(Icons.close, size: 16, color: Colors.grey.withOpacity(0.6)),
                    ),
                ]),
              ),
            ),
            const SizedBox(height: 10),

            // Note
            TextField(
              controller: _noteCtrl,
              maxLines: 3,
              style: TextStyle(fontSize: 13, color: txt),
              decoration: _inputDec(ru ? 'Заметка, место, детали...' : 'Note, place, details...', dark)
                  .copyWith(
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: c, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                    side: BorderSide(color: Colors.grey.withOpacity(0.3)),
                  ),
                  child: Text(ru ? 'Отмена' : 'Cancel',
                      style: TextStyle(color: txt.withOpacity(0.5))),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                  ),
                  child: Text(ru ? 'Сохранить' : 'Save',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

// ─── Shared helpers ───────────────────────────────────────────────────────────

Widget _handle() => Container(
  width: 40, height: 4,
  decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2)),
);

InputDecoration _inputDec(String hint, bool dark) => InputDecoration(
  hintText: hint,
  hintStyle: TextStyle(color: dark ? Colors.white38 : Colors.grey, fontSize: 13),
  filled: true,
  fillColor: dark ? Colors.white.withOpacity(0.06) : Colors.grey.withOpacity(0.07),
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
  focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF5A8FDB), width: 1.5)),
  contentPadding: const EdgeInsets.all(12),
);

// ─── Menu & Nav ───────────────────────────────────────────────────────────────

class _MenuBtn extends StatelessWidget {
  final AppState st;
  const _MenuBtn({required this.st});

  @override
  Widget build(BuildContext context) {
    final dark = st.isDark;
    final ru = st.isRu;
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert_rounded,
          color: dark ? Colors.white70 : const Color(0xFF4A4E69)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: dark ? const Color(0xFF2E3250) : Colors.white,
      elevation: 8,
      onSelected: (v) async {
        if (v == 'theme') await st.toggleTheme();
        if (v == 'lang') await st.toggleLanguage();
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'theme',
          child: Row(children: [
            Icon(dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                color: dark ? Colors.amber : const Color(0xFF5A8FDB), size: 20),
            const SizedBox(width: 10),
            Text(dark ? (ru ? 'Светлая тема' : 'Light') : (ru ? 'Тёмная тема' : 'Dark'),
                style: TextStyle(
                    color: dark ? Colors.white : const Color(0xFF1A1D2E),
                    fontWeight: FontWeight.w500)),
          ]),
        ),
        PopupMenuItem(
          value: 'lang',
          child: Row(children: [
            Text(ru ? '🇬🇧' : '🇷🇺', style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Text(ru ? 'English' : 'Русский',
                style: TextStyle(
                    color: dark ? Colors.white : const Color(0xFF1A1D2E),
                    fontWeight: FontWeight.w500)),
          ]),
        ),
      ],
    );
  }
}

class _Arrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool dark;
  const _Arrow({required this.icon, required this.onTap, required this.dark});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 34, height: 34,
      decoration: BoxDecoration(
        color: dark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 20, color: dark ? Colors.white70 : const Color(0xFF4A4E69)),
    ),
  );
}
