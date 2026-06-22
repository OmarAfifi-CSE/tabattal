import 'dart:io';

import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';

import 'exceptions.dart';

abstract class Failure extends Equatable {
  final String message;
  const Failure(this.message);

  factory Failure.fromException(Object e) {
    if (e is ServerException) return ServerFailure(e.message);
    if (e is NetworkException) return NetworkFailure(e.message);
    if (e is CacheException) return CacheFailure(e.message);
    if (e is DioException) return ServerFailure(e.message ?? 'Network error');
    if (e is SocketException) return NetworkFailure(e.message);
    return _UnknownFailure(e.toString());
  }

  @override
  List<Object> get props => [message];
}

class _UnknownFailure extends Failure {
  const _UnknownFailure(super.message);
}

class ServerFailure extends Failure {
  const ServerFailure(super.message);
}

class NetworkFailure extends Failure {
  const NetworkFailure(super.message);
}

class CacheFailure extends Failure {
  const CacheFailure(super.message);
}
