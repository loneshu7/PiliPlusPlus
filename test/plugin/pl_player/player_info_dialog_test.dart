import 'package:PiliPlus/plugin/pl_player/models/player_media_track.dart';
import 'package:PiliPlus/plugin/pl_player/widgets/player_info_dialog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('opens with the app material_ui localizations', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
        locale: const Locale('zh', 'CN'),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showPlayerInfoDialog(
              context,
              const [PlayerInfoEntry('VideoDecoder', 'c2.qti.avc.decoder')],
            ),
            child: const Text('打开'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('播放信息'), findsOneWidget);
    expect(find.text('VideoDecoder'), findsOneWidget);
    expect(find.text('c2.qti.avc.decoder'), findsOneWidget);
  });
}
