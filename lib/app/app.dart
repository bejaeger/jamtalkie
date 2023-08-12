import 'package:jamtalkie/ui/bottom_sheets/notice/notice_sheet.dart';
import 'package:jamtalkie/ui/dialogs/info_alert/info_alert_dialog.dart';
import 'package:jamtalkie/ui/views/home/home_view.dart';
import 'package:jamtalkie/ui/views/startup/startup_view.dart';
import 'package:stacked/stacked_annotations.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:jamtalkie/ui/views/jamtalkie_home/jamtalkie_home_view.dart';
import 'package:jamtalkie/services/audio_service_service.dart';
import 'package:jamtalkie/services/firebase_service.dart';
import 'package:jamtalkie/services/porcupine_service.dart';
// @stacked-import

@StackedApp(
  logger: StackedLogger(),
  routes: [
    MaterialRoute(page: HomeView),
    MaterialRoute(page: StartupView),
    MaterialRoute(page: JamtalkieHomeView),
// @stacked-route
  ],
  dependencies: [
    LazySingleton(classType: BottomSheetService),
    LazySingleton(classType: DialogService),
    LazySingleton(classType: SnackbarService),
    LazySingleton(classType: NavigationService),
    LazySingleton(classType: AudioServiceService),
    LazySingleton(classType: FirebaseService),
    LazySingleton(classType: PorcupineService),
// @stacked-service
  ],
  bottomsheets: [
    StackedBottomsheet(classType: NoticeSheet),
    // @stacked-bottom-sheet
  ],
  dialogs: [
    StackedDialog(classType: InfoAlertDialog),
    // @stacked-dialog
  ],
)
class App {}
