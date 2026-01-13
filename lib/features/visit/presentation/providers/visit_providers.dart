import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../shared/services/odoo_jsonrpc_client.dart';

import '../../data/visit_remote_data_source.dart';
import '../../data/visit_repository_impl.dart';
import '../../domain/visit_repository.dart';
import '../controllers/visit_controller.dart';

// ✅ nuovo import visitor datasource
import '../../../visitor/data/visitor_remote_data_source.dart';

final odooClientProvider = Provider<OdooJsonRpcClient>((ref) {
  return OdooJsonRpcClient(
    baseUrl: AppConfig.odooBaseUrl,
    db: AppConfig.odooDb,
    username: AppConfig.odooUsername,
    password: AppConfig.odooPassword,
  );
});

final visitRemoteDataSourceProvider = Provider<VisitRemoteDataSource>((ref) {
  final odoo = ref.watch(odooClientProvider);
  return VisitRemoteDataSource(odoo);
});

// ✅ nuovo provider visitor datasource
final visitorRemoteDataSourceProvider = Provider<VisitorRemoteDataSource>((ref) {
  final odoo = ref.watch(odooClientProvider);
  return VisitorRemoteDataSource(odoo);
});

final visitRepositoryProvider = Provider<VisitRepository>((ref) {
  final visitDs = ref.watch(visitRemoteDataSourceProvider);
  final visitorDs = ref.watch(visitorRemoteDataSourceProvider);
  return VisitRepositoryImpl(visitDs, visitorDs);
});

final visitControllerProvider =
StateNotifierProvider<VisitController, VisitState>((ref) {
  final repo = ref.watch(visitRepositoryProvider);
  return VisitController(repo);
});
