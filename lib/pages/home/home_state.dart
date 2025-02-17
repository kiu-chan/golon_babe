import 'package:flutter/material.dart';
import 'package:golon_babe/models/tree_model.dart';

@immutable
class HomeState {
  final List<MasterTreeInfo> masterTreeList;
  final bool isLoading;
  final bool isSyncing;
  final bool isOnline;
  final bool isInitialized;
  final String? errorMessage;
  final String? successMessage;
  final DateTime? lastSyncDate;

  const HomeState({
    this.masterTreeList = const [],
    this.isLoading = true,
    this.isSyncing = false,
    this.isOnline = true,
    this.isInitialized = false,
    this.errorMessage,
    this.successMessage,
    this.lastSyncDate,
  });

  HomeState copyWith({
    List<MasterTreeInfo>? masterTreeList,
    bool? isLoading,
    bool? isSyncing,
    bool? isOnline,
    bool? isInitialized,
    String? errorMessage,
    String? successMessage,
    DateTime? lastSyncDate,
  }) {
    return HomeState(
      masterTreeList: masterTreeList ?? this.masterTreeList,
      isLoading: isLoading ?? this.isLoading,
      isSyncing: isSyncing ?? this.isSyncing,
      isOnline: isOnline ?? this.isOnline,
      isInitialized: isInitialized ?? this.isInitialized,
      errorMessage: errorMessage,
      successMessage: successMessage,
      lastSyncDate: lastSyncDate ?? this.lastSyncDate,
    );
  }

  bool get isEmpty => masterTreeList.isEmpty;
  bool get hasError => errorMessage != null;
  bool get hasSuccess => successMessage != null;
  bool get needsSync => lastSyncDate == null || 
    DateTime.now().difference(lastSyncDate!).inHours >= 1;

  @override
  bool operator ==(Object other) =>
    identical(this, other) ||
    other is HomeState &&
    runtimeType == other.runtimeType &&
    masterTreeList == other.masterTreeList &&
    isLoading == other.isLoading &&
    isSyncing == other.isSyncing &&
    isOnline == other.isOnline &&
    isInitialized == other.isInitialized &&
    errorMessage == other.errorMessage &&
    successMessage == other.successMessage &&
    lastSyncDate == other.lastSyncDate;

  @override
  int get hashCode =>
    masterTreeList.hashCode ^
    isLoading.hashCode ^
    isSyncing.hashCode ^
    isOnline.hashCode ^
    isInitialized.hashCode ^
    errorMessage.hashCode ^
    successMessage.hashCode ^
    lastSyncDate.hashCode;

  @override
  String toString() {
    return '''HomeState(
      masterTreeList: ${masterTreeList.length} items,
      isLoading: $isLoading,
      isSyncing: $isSyncing,
      isOnline: $isOnline,
      isInitialized: $isInitialized,
      errorMessage: $errorMessage,
      successMessage: $successMessage,
      lastSyncDate: $lastSyncDate
    )''';
  }
}