/// Screen 3 of 6 — Three doors off the page.
///
/// Halaqa, Minbar, Growth. Three rooms, three arches, and — deliberately — only
/// three: Quran and Discover go unmentioned here because this screen exists to
/// say "Mizan is more than a book", and listing the book's own two rooms among
/// the three that prove it would undo the sentence.
///
/// ── All three arches are the same size ────────────────────────────────
/// Selection is carried by light alone. The obvious design — grow the focused
/// door — is rejected because it makes the other two rooms look like lesser
/// features rather than equal rooms, and because a layout that reflows on every
/// tap is a layout that jumps. The focused door gets a full-strength gold edge
/// and a faint upward wash; the other two sit at opacity .75, which is the floor
/// for their Arabic names to stay legible.
///
/// ── The chip, and what it is allowed to say ───────────────────────────
/// The brief calls the live chip the point of this screen, and forbids inventing
/// a number for it. One of the three can genuinely be live before sign-in —
/// Minbar, whose feed is readable by the anon role. The other two cannot, and
/// say something true instead of something numeric. The full reasoning is in
/// `onboarding_live_data.dart`, which is where the count comes from.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/onboarding_live_data.dart';
import '../widgets/onboarding_kit.dart';

class OnbRoomsPage extends ConsumerStatefulWidget {
  const OnbRoomsPage({
    super.key,
    required this.onContinue,
    required this.onSkip,
  });

  final VoidCallback onContinue;
  final VoidCallback onSkip;

  @override
  ConsumerState<OnbRoomsPage> createState() => _OnbRoomsPageState();
}

class _OnbRoomsPageState extends ConsumerState<OnbRoomsPage> {
  int _focused = 0;

  @override
  Widget build(BuildContext context) {
    final minbarCount = ref.watch(minbarWeekCountProvider);
    const rooms = _rooms;
    final room = rooms[_focused];

    return OnbScaffold(
      step: 2,
      onSkip: widget.onSkip,
      footer: OnbPrimaryButton(label: 'Continue', onTap: widget.onContinue),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const OnbEyebrow('More than a book'),
          const SizedBox(height: 12),
          Text('Three doors off the page', style: OnbType.heading()),
          const SizedBox(height: 26),

          // The focused room's own sentence, and its chip. Both change with the
          // focus; both are centred over the doors rather than left-aligned with
          // the heading, so the eye reads them as belonging to the arch beneath.
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 290),
              child: Text(
                room.description,
                style: OnbType.quote(fontSize: 19, color: OnbTok.paper),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: _LiveChip(
              text: room.chip(minbarCount.valueOrNull),
            ),
          ),
          const SizedBox(height: 26),

          // The arch row, its floor line and the glow beneath are one block.
          // Absolutely positioning the floor against the frame instead would
          // leave it drifting away from the doors on every screen height that is
          // not 844 tall.
          _DoorRow(
            rooms: rooms,
            focused: _focused,
            onFocus: (i) => setState(() => _focused = i),
          ),
        ],
      ),
    );
  }
}

// ── The chip ────────────────────────────────────────────────────────────

class _LiveChip extends StatelessWidget {
  const _LiveChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        color: OnbTok.gold08,
        border: Border.all(color: OnbTok.gold30),
        borderRadius: BorderRadius.circular(OnbTok.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: OnbTok.gold,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: OnbType.sans(fontSize: 12, height: 1.35),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

// ── The three arches ────────────────────────────────────────────────────

class _DoorRow extends StatelessWidget {
  const _DoorRow({
    required this.rooms,
    required this.focused,
    required this.onFocus,
  });

  final List<_Room> rooms;
  final int focused;
  final ValueChanged<int> onFocus;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < rooms.length; i++) ...[
              if (i > 0) const SizedBox(width: 14),
              _Door(
                room: rooms[i],
                focused: i == focused,
                onTap: () => onFocus(i),
              ),
            ],
          ],
        ),
        // The floor: a hairline that fades out at both ends, so the three doors
        // stand on something without the line reading as a table edge.
        Container(
          height: 1,
          margin: const EdgeInsets.only(top: 1),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0x00D8B45A),
                OnbTok.gold45,
                Color(0x00D8B45A),
              ],
            ),
          ),
        ),
        // The light the doors are standing in. Drawn below the floor and clipped
        // to its own height so it reads as spill rather than as a halo.
        const _FloorGlow(),
      ],
    );
  }
}

class _Door extends StatelessWidget {
  const _Door({
    required this.room,
    required this.focused,
    required this.onTap,
  });

  final _Room room;
  final bool focused;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // 96 is the brief's width, but three of them plus two 14pt gaps plus the
    // 24pt gutters needs 364 — more than a 360pt phone has. So the width is
    // capped by what is available and the doors shrink together rather than one
    // of them being pushed out of the row.
    final available = MediaQuery.sizeOf(context).width - OnbTok.gutter * 2 - 28;
    final width = available / 3 < 96 ? available / 3 : 96.0;

    final door = Semantics(
      button: true,
      selected: focused,
      label: '${room.english}. ${room.description}',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: width,
          height: 146,
          child: CustomPaint(
            painter: _DoorPainter(focused: focused),
            child: Padding(
              // Room for the arch's own curve, so the icon does not sit inside
              // the shoulder of the arc.
              padding: const EdgeInsets.only(top: 30, bottom: 14),
              child: Column(
                children: [
                  Icon(room.icon, size: 24, color: OnbTok.gold),
                  const Spacer(),
                  Text(
                    room.arabic,
                    style: OnbType.arabic(fontSize: 17, height: 1.4)
                        .copyWith(color: OnbTok.gold),
                    textDirection: TextDirection.rtl,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    room.english,
                    style: OnbType.sans(
                      fontSize: 12.5,
                      weight: FontWeight.w600,
                      color: OnbTok.paper,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // .75 is a floor, not a preference: below it the Amiri names on the two
    // unfocused doors stop being readable against ink.
    return focused ? door : Opacity(opacity: 0.75, child: door);
  }
}

/// One three-sided arch: `border-bottom: none`, radius exactly half the width.
///
/// A [BoxDecoration] cannot do this — it asserts that a border with unequal
/// sides may not also carry a radius — so the arch is a path, and the wash
/// inside it is the same path filled.
class _DoorPainter extends CustomPainter {
  const _DoorPainter({required this.focused});

  final bool focused;

  @override
  void paint(Canvas canvas, Size size) {
    const half = 0.5;
    final r = size.width / 2 - half;
    final path = Path()
      ..moveTo(half, size.height)
      ..lineTo(half, r + half)
      ..arcToPoint(
        Offset(size.width - half, r + half),
        radius: Radius.circular(r),
        clockwise: true,
      )
      ..lineTo(size.width - half, size.height);

    // The fill has to be closed or it will not cover the lower half of the box.
    final fillPath = Path.from(path)..close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = (focused
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [OnbTok.gold16, OnbTok.gold03],
                  )
                : const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [OnbTok.paper025, OnbTok.paper025],
                  ))
            .createShader(Offset.zero & size),
    );

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = focused ? OnbTok.gold : OnbTok.gold22,
    );
  }

  @override
  bool shouldRepaint(_DoorPainter old) => old.focused != focused;
}

class _FloorGlow extends StatelessWidget {
  const _FloorGlow();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ExcludeSemantics(
        child: SizedBox(
          height: 62,
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.topCenter,
              maxHeight: 250,
              child: SizedBox(
                width: 430,
                height: 250,
                // The same scaled-circle trick as the welcome screen's horizon:
                // Flutter's radial gradient is circular, and an ellipse is a
                // circle with one axis stretched.
                child: Transform.scale(
                  scaleY: 250 / 125,
                  alignment: Alignment.topCenter,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.topCenter,
                        radius: 0.5,
                        colors: [OnbTok.gold15, Color(0x000A2233)],
                        stops: [0.0, 0.7],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── The rooms ───────────────────────────────────────────────────────────

@immutable
class _Room {
  const _Room({
    required this.icon,
    required this.arabic,
    required this.english,
    required this.description,
    required this.chip,
  });

  final IconData icon;
  final String arabic;
  final String english;
  final String description;

  /// Given the live Minbar count — or null when it is unknown — the sentence the
  /// chip should show. A function rather than a string precisely so that the one
  /// room with real data can use it and the two without it cannot pretend to.
  final String Function(int? minbarWeekCount) chip;
}

const _rooms = <_Room>[
  // Material glyphs, not the app's PNG icon set. Two reasons: the brief bans
  // image files everywhere in this flow except the app mark, and MizanIcon has
  // no colour parameter by design, so it cannot be rendered in gold. The brief
  // names Material glyphs for every other icon in the flow, so this is its own
  // vocabulary rather than a substitution.
  _Room(
    icon: Icons.people_outline,
    arabic: 'حَلقَة',
    english: 'Halaqa',
    description: 'Read the same ayah as a circle, at the same time, and '
        'leave your notes for each other.',
    // Not a count. `halaqas` and `halaqa_members` are readable only by an
    // authenticated role — correctly, a private circle is not public — and this
    // screen runs before sign-in. So the chip carries a fact that is true
    // whether or not anybody has made a circle yet.
    chip: _halaqaChip,
  ),
  _Room(
    icon: Icons.record_voice_over_outlined,
    arabic: 'مِنْبَر',
    english: 'Minbar',
    // The mockup's line is "Short talks from teachers you can check". Mizan's
    // Minbar is not that: it is a public feed where people share an ayah or a
    // hadith with a note under a hundred characters, three reactions and no
    // comments. Describing it as teacher talks would promise a room that does
    // not exist, which is a worse failure than a wrong number.
    description: 'What people are reading, shared in public — every post '
        'tied to the ayah or hadith it came from.',
    chip: _minbarChip,
  ),
  _Room(
    icon: Icons.eco_outlined,
    arabic: 'نُمُو',
    english: 'Growth',
    description: "What you've understood, not days logged in — roots "
        'learned, surahs opened, questions left open.',
    chip: _growthChip,
  ),
];

String _halaqaChip(int? _) => 'Two to eight people, by invite code';

String _minbarChip(int? weekCount) {
  // Null is "we could not ask", which must not render as "nothing is here".
  if (weekCount == null) return 'Open to everyone — no comments, ever';
  if (weekCount == 0) return 'Nothing shared this week — be the first';
  if (weekCount == 1) return 'New this week — 1 post';
  return 'New this week — $weekCount posts';
}

String _growthChip(int? _) => 'Starts counting from your first ayah';
