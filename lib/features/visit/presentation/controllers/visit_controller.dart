import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/visit.dart';
import '../../domain/visit_repository.dart';

class VisitState {
  final Visit? currentVisit;
  final bool isLoading;
  final String? errorMessage;

  const VisitState({
    this.currentVisit,
    this.isLoading = false,
    this.errorMessage,
  });

  VisitState copyWith({
    Visit? currentVisit,
    bool? isLoading,
    String? errorMessage,
  }) {
    return VisitState(
      currentVisit: currentVisit ?? this.currentVisit,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }

  static const initial = VisitState();
}

class VisitController extends StateNotifier<VisitState> {
  VisitController(this._repository) : super(VisitState.initial);

  final VisitRepository _repository;

  void reset() {
    state = VisitState.initial;
  }

  /// ✅ Crea una nuova visita in Odoo (draft).
  /// Ora include anche title + company (che poi finiscono nel record visitatore su Odoo)
  Future<void> createVisit({
    required String firstName,
    required String lastName,

    // ✅ NUOVO: titolo (Sig., Dott., Ing...)
    String? title,

    String? reason,
    String? company,
    String? docType,
    String? docNumber,
    String? hostName,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final visit = await _repository.createVisit(
        firstName: firstName,
        lastName: lastName,
        title: title, // ✅ passa al repository
        reason: reason,
        company: company,
        docType: docType,
        docNumber: docNumber,
        hostName: hostName,
      );

      state = state.copyWith(currentVisit: visit, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _cleanError(e),
      );
    }
  }

  Future<void> acceptPrivacy() async {
    final current = state.currentVisit;
    if (current == null) {
      state = state.copyWith(errorMessage: 'Nessuna visita corrente');
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final saved = await _repository.acceptPrivacy(current);
      state = state.copyWith(currentVisit: saved, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _cleanError(e),
      );
    }
  }

  Future<void> assignBadgeAndCheckIn({required String badgeCode}) async {
    final current = state.currentVisit;
    if (current == null) {
      state = state.copyWith(errorMessage: 'Nessuna visita corrente');
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final saved = await _repository.assignBadgeAndCheckIn(
        visit: current,
        badgeCode: badgeCode,
      );

      state = state.copyWith(currentVisit: saved, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _cleanError(e),
      );
    }
  }

  Future<void> acceptPrivacyWithSignature({
    required String signaturePngBase64,
  }) async {
    final current = state.currentVisit;
    if (current == null) {
      state = state.copyWith(errorMessage: 'Nessuna visita corrente');
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final saved = await _repository.acceptPrivacyWithSignature(
        visit: current,
        signaturePngBase64: signaturePngBase64,
      );

      state = state.copyWith(currentVisit: saved, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _cleanError(e),
      );
    }
  }

  Future<void> checkOutByBadgeCode({required String badgeCode}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      await _repository.checkOutByBadgeCode(badgeCode: badgeCode);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _cleanError(e),
      );
    }
  }

  String _cleanError(Object e) {
    final s = e.toString();
    return s.replaceFirst('Exception: ', '').trim();
  }
}
