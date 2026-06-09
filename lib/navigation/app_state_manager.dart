import 'package:flutter/material.dart';
import 'package:habo/model/habit_data.dart';

class AppStateManager extends ChangeNotifier {
  bool _statistics = false;
  bool _settings = false;
  bool _onboarding = false;
  bool _whatsNew = false;
  bool _createHabit = false;
  bool _friends = false;
  bool _activity = false;
  bool _help = false;
  HabitData? _editHabit;

  bool get getStatistics => _statistics;
  bool get getSettings => _settings;
  bool get getOnboarding => _onboarding;
  bool get getWhatsNew => _whatsNew;
  bool get getCreateHabit => _createHabit;
  bool get getFriends => _friends;
  bool get getActivity => _activity;
  bool get getHelp => _help;
  HabitData? get getEditHabit => _editHabit;

  void goStatistics(bool state) {
    _statistics = state;
    notifyListeners();
  }

  void goSettings(bool state) {
    _settings = state;
    notifyListeners();
  }

  void goOnboarding(bool state) {
    _onboarding = state;
    notifyListeners();
  }

  void goWhatsNew(bool state) {
    _whatsNew = state;
    notifyListeners();
  }

  void goHelp(bool state) {
    _help = state;
    notifyListeners();
  }

  void goCreateHabit(bool state) {
    _createHabit = state;
    notifyListeners();
  }

  void goFriends(bool state) {
    _friends = state;
    notifyListeners();
  }

  void goActivity(bool state) {
    _activity = state;
    notifyListeners();
  }

  void goEditHabit(HabitData? habitData) {
    _editHabit = habitData;
    notifyListeners();
  }
}
