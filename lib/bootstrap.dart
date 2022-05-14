import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';

import 'app.dart';
import 'app_bloc_observer.dart';

final logger = Logger(
  printer: PrettyPrinter()
);

void bootstrap() {
  FlutterError.onError = (details) {
    log(details.exceptionAsString(), stackTrace: details.stack);
  };

  BlocOverrides.runZoned(() => runApp(App()), blocObserver: AppBlocObserver());
}
