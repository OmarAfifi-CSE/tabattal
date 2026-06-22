import 'failures.dart';

typedef Result<T> = Either<Failure, T>;

sealed class Either<L, R> {
  const Either();

  T fold<T>(T Function(L left) onLeft, T Function(R right) onRight);

  Either<L, T> map<T>(T Function(R right) fn) {
    return fold(
      (left) => Left(left),
      (right) => Right(fn(right)),
    );
  }

  R? getOrNull() => fold((_) => null, (r) => r);

  L? failureOrNull() => fold((l) => l, (_) => null);

  bool get isLeft => this is Left<L, R>;
  bool get isRight => this is Right<L, R>;
}

class Left<L, R> extends Either<L, R> {
  final L value;
  const Left(this.value);

  @override
  T fold<T>(T Function(L left) onLeft, T Function(R right) onRight) => onLeft(value);
}

class Right<L, R> extends Either<L, R> {
  final R value;
  const Right(this.value);

  @override
  T fold<T>(T Function(L left) onLeft, T Function(R right) onRight) => onRight(value);
}
