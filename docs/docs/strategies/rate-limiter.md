---
sidebar_position: 7
---

# Rate Limiter Strategy

The **Rate Limiter Strategy** controls the rate of execution to prevent overwhelming resources and ensure fair usage. It acts as a traffic control system, queuing or rejecting requests when limits are exceeded, protecting both your application and downstream services.

## When to Use Rate Limiter

Rate limiting is essential for:

- 🛡️ **Protecting APIs** from being overwhelmed by too many requests
- ⚖️ **Fair resource sharing** among multiple consumers or tenants
- 🏗️ **Bulkhead isolation** to prevent one component from affecting others
- 💰 **Cost control** for pay-per-request cloud services
- 🚦 **Traffic shaping** during high-load periods
- 🔒 **Compliance** with third-party API rate limits
- 🎯 **SLA enforcement** to maintain service quality

:::tip Proactive Protection
Rate limiting is a proactive strategy that prevents problems before they occur, unlike reactive strategies that respond to failures.
:::

## Basic Usage

### Simple Rate Limiting
```dart
import 'package:polly_dart/polly_dart.dart';

final pipeline = ResiliencePipelineBuilder()
    .addRateLimiter(RateLimiterStrategyOptions(
      permitLimit: 10, // Allow 10 requests
      window: Duration(seconds: 1), // Per second
    ))
    .build();

final result = await pipeline.execute((context) async {
  return await callExternalApi();
});
// Throws RateLimiterRejectedException if limit exceeded
```

### Rate Limiting with Queuing
```dart
final queueingPipeline = ResiliencePipelineBuilder()
    .addRateLimiter(RateLimiterStrategyOptions(
      permitLimit: 5,
      window: Duration(seconds: 1),
      queueLimit: 10, // Queue up to 10 requests
    ))
    .build();

// Requests will be queued if rate limit is exceeded
final result = await queueingPipeline.execute((context) async {
  return await processRequest();
});
```

## Configuration Options

### RateLimiterStrategyOptions

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `permitLimit` | `int` | Required | Number of permits available in the time window |
| `window` | `Duration` | Required | Time window for the permit limit |
| `queueLimit` | `int?` | `null` | Maximum number of requests to queue (null = no queuing) |
| `autoReplenishment` | `bool` | `true` | Whether permits replenish automatically over time |
| `onRejected` | `OnRateLimiterRejectedCallback?` | `null` | Callback when request is rejected |
| `onQueued` | `OnRateLimiterQueuedCallback?` | `null` | Callback when request is queued |

### Type Definitions

```dart
typedef OnRateLimiterRejectedCallback = Future<void> Function(OnRateLimiterRejectedArguments args);
typedef OnRateLimiterQueuedCallback = Future<void> Function(OnRateLimiterQueuedArguments args);
```

## Rate Limiting Patterns

### Fixed Window Rate Limiting
Classic rate limiting with fixed time windows:

```dart
final fixedWindowPipeline = ResiliencePipelineBuilder()
    .addRateLimiter(RateLimiterStrategyOptions(
      permitLimit: 100, // 100 requests
      window: Duration(minutes: 1), // Per minute
      onRejected: (args) async {
        logger.warning('Rate limit exceeded, request rejected');
        metrics.incrementCounter('rate_limit_rejections');
      },
    ))
    .build();

Future<ApiResponse> callApi(String endpoint) async {
  try {
    return await fixedWindowPipeline.execute((context) async {
      return await httpClient.get(endpoint);
    });
  } on RateLimiterRejectedException {
    // Handle rate limit exceeded
    throw ApiException('Rate limit exceeded, please try again later');
  }
}
```

### Sliding Window Rate Limiting
More sophisticated rate limiting with sliding windows:

```dart
class SlidingWindowRateLimiter {
  final Map<String, List<DateTime>> _requestHistory = {};
  final int _permitLimit;
  final Duration _window;

  SlidingWindowRateLimiter(this._permitLimit, this._window);

  bool tryAcquirePermit(String key) {
    final now = DateTime.now();
    final history = _requestHistory.putIfAbsent(key, () => <DateTime>[]);
    
    // Remove expired requests
    history.removeWhere((timestamp) => 
        now.difference(timestamp) > _window);
    
    if (history.length < _permitLimit) {
      history.add(now);
      return true;
    }
    
    return false;
  }
}

final slidingWindowPipeline = ResiliencePipelineBuilder()
    .addRateLimiter(RateLimiterStrategyOptions(
      permitLimit: 50,
      window: Duration(seconds: 30),
      autoReplenishment: true,
    ))
    .build();
```

### Multi-Tier Rate Limiting
Different limits for different user tiers:

```dart
class TieredRateLimiterService {
  final Map<UserTier, ResiliencePipeline> _pipelines = {};

  TieredRateLimiterService() {
    _pipelines[UserTier.free] = _createPipeline(
      permitLimit: 10,
      window: Duration(minutes: 1),
      queueLimit: 5,
    );
    
    _pipelines[UserTier.premium] = _createPipeline(
      permitLimit: 100,
      window: Duration(minutes: 1),
      queueLimit: 20,
    );
    
    _pipelines[UserTier.enterprise] = _createPipeline(
      permitLimit: 1000,
      window: Duration(minutes: 1),
      queueLimit: 100,
    );
  }

  ResiliencePipeline _createPipeline({
    required int permitLimit,
    required Duration window,
    required int queueLimit,
  }) {
    return ResiliencePipelineBuilder()
        .addRateLimiter(RateLimiterStrategyOptions(
          permitLimit: permitLimit,
          window: window,
          queueLimit: queueLimit,
          onRejected: _onRateLimitRejected,
          onQueued: _onRequestQueued,
        ))
        .build();
  }

  Future<T> execute<T>(
    UserTier tier,
    Future<T> Function(ResilienceContext) operation,
  ) async {
    final pipeline = _pipelines[tier]!;
    
    final context = ResilienceContext();
    context.setProperty('userTier', tier.toString());
    
    return await pipeline.execute(operation, context: context);
  }

  Future<void> _onRateLimitRejected(OnRateLimiterRejectedArguments args) async {
    final tier = args.context.getProperty<String>('userTier') ?? 'unknown';
    
    logger.warning('Rate limit exceeded for tier: $tier');
    metrics.incrementCounter('rate_limit_rejections', tags: {'tier': tier});
  }

  Future<void> _onRequestQueued(OnRateLimiterQueuedArguments args) async {
    final tier = args.context.getProperty<String>('userTier') ?? 'unknown';
    
    logger.debug('Request queued for tier: $tier');
    metrics.incrementCounter('rate_limit_queued', tags: {'tier': tier});
  }
}

enum UserTier { free, premium, enterprise }
```

### Per-User Rate Limiting
Individual rate limits for each user:

```dart
class PerUserRateLimiterService {
  final Map<int, ResiliencePipeline> _userPipelines = {};
  final Duration _cleanupInterval = Duration(minutes: 5);
  Timer? _cleanupTimer;

  PerUserRateLimiterService() {
    _startCleanupTimer();
  }

  Future<T> executeForUser<T>(
    int userId,
    Future<T> Function(ResilienceContext) operation,
  ) async {
    final pipeline = _getUserPipeline(userId);
    
    final context = ResilienceContext();
    context.setProperty('userId', userId);
    
    return await pipeline.execute(operation, context: context);
  }

  ResiliencePipeline _getUserPipeline(int userId) {
    return _userPipelines.putIfAbsent(userId, () => 
        ResiliencePipelineBuilder()
            .addRateLimiter(RateLimiterStrategyOptions(
              permitLimit: 20, // 20 requests per user
              window: Duration(minutes: 1),
              queueLimit: 5,
              onRejected: (args) => _onUserRateLimitExceeded(userId, args),
            ))
            .build()
    );
  }

  Future<void> _onUserRateLimitExceeded(
    int userId,
    OnRateLimiterRejectedArguments args,
  ) async {
    logger.warning('Rate limit exceeded for user: $userId');
    
    // Could trigger user notification or temporary suspension
    await userNotificationService.notifyRateLimitExceeded(userId);
    
    metrics.incrementCounter('per_user_rate_limit_exceeded', tags: {
      'user_id': userId.toString(),
    });
  }

  void _startCleanupTimer() {
    _cleanupTimer = Timer.periodic(_cleanupInterval, (_) {
      _cleanupInactivePipelines();
    });
  }

  void _cleanupInactivePipelines() {
    // Remove pipelines for users who haven't made requests recently
    // Implementation depends on tracking last usage time
  }

  void dispose() {
    _cleanupTimer?.cancel();
  }
}
```

### Adaptive Rate Limiting
Dynamically adjust limits based on system load:

```dart
class AdaptiveRateLimiterService {
  late ResiliencePipeline _pipeline;
  int _currentPermitLimit = 100;
  final int _basePermitLimit = 100;
  final SystemLoadMonitor _loadMonitor;

  AdaptiveRateLimiterService(this._loadMonitor) {
    _createPipeline();
    _startLoadMonitoring();
  }

  void _createPipeline() {
    _pipeline = ResiliencePipelineBuilder()
        .addRateLimiter(RateLimiterStrategyOptions(
          permitLimit: _currentPermitLimit,
          window: Duration(seconds: 1),
          queueLimit: _currentPermitLimit ~/ 2,
          onRejected: _onRateLimitRejected,
        ))
        .build();
  }

  Future<T> execute<T>(Future<T> Function(ResilienceContext) operation) async {
    return await _pipeline.execute(operation);
  }

  void _startLoadMonitoring() {
    Timer.periodic(Duration(seconds: 5), (_) => _adjustLimits());
  }

  void _adjustLimits() {
    final load = _loadMonitor.getCurrentLoad();
    int newPermitLimit;

    if (load > 0.9) {
      // High load: reduce rate limit by 50%
      newPermitLimit = (_basePermitLimit * 0.5).round();
    } else if (load > 0.7) {
      // Medium load: reduce rate limit by 25%
      newPermitLimit = (_basePermitLimit * 0.75).round();
    } else if (load < 0.3) {
      // Low load: increase rate limit by 25%
      newPermitLimit = (_basePermitLimit * 1.25).round();
    } else {
      // Normal load: use base limit
      newPermitLimit = _basePermitLimit;
    }

    if (newPermitLimit != _currentPermitLimit) {
      logger.info('Adjusting rate limit from $_currentPermitLimit to $newPermitLimit (load: ${(load * 100).toStringAsFixed(1)}%)');
      
      _currentPermitLimit = newPermitLimit;
      _createPipeline(); // Recreate pipeline with new limits
      
      metrics.setGauge('adaptive_rate_limit', _currentPermitLimit.toDouble());
    }
  }

  Future<void> _onRateLimitRejected(OnRateLimiterRejectedArguments args) async {
    logger.warning('Adaptive rate limit rejection (current limit: $_currentPermitLimit)');
    metrics.incrementCounter('adaptive_rate_limit_rejections');
  }
}

class SystemLoadMonitor {
  double getCurrentLoad() {
    // Implementation to get current system load
    // Could monitor CPU, memory, active connections, etc.
    return 0.5; // Placeholder
  }
}
```

## Advanced Rate Limiting Patterns

### Distributed Rate Limiting
Rate limiting across multiple application instances:

```dart
class DistributedRateLimiterService {
  final RedisClient _redis;
  final String _keyPrefix;
  final Duration _window;
  final int _permitLimit;

  DistributedRateLimiterService(
    this._redis,
    this._keyPrefix,
    this._permitLimit,
    this._window,
  );

  late final ResiliencePipeline _pipeline = ResiliencePipelineBuilder()
      .addRateLimiter(RateLimiterStrategyOptions(
        permitLimit: _permitLimit,
        window: _window,
        // Custom permit acquisition using Redis
        onRejected: _onDistributedRateLimitRejected,
      ))
      .build();

  Future<bool> tryAcquireDistributedPermit(String key) async {
    final redisKey = '$_keyPrefix:$key';
    final windowStart = DateTime.now().millisecondsSinceEpoch ~/ _window.inMilliseconds;
    final redisWindowKey = '$redisKey:$windowStart';

    // Use Redis atomic operations for distributed counting
    final pipeline = _redis.pipeline();
    pipeline.incr(redisWindowKey);
    pipeline.expire(redisWindowKey, _window.inSeconds);
    
    final results = await pipeline.exec();
    final currentCount = results[0] as int;

    return currentCount <= _permitLimit;
  }

  Future<T> execute<T>(
    String rateLimitKey,
    Future<T> Function(ResilienceContext) operation,
  ) async {
    final context = ResilienceContext();
    context.setProperty('rateLimitKey', rateLimitKey);

    // Check distributed rate limit first
    if (!await tryAcquireDistributedPermit(rateLimitKey)) {
      throw RateLimiterRejectedException('Distributed rate limit exceeded');
    }

    return await _pipeline.execute(operation, context: context);
  }

  Future<void> _onDistributedRateLimitRejected(
    OnRateLimiterRejectedArguments args,
  ) async {
    final key = args.context.getProperty<String>('rateLimitKey');
    
    logger.warning('Distributed rate limit exceeded for key: $key');
    metrics.incrementCounter('distributed_rate_limit_rejections', tags: {
      'key': key ?? 'unknown',
    });
  }
}
```

### Token Bucket Rate Limiting
More flexible rate limiting allowing burst traffic:

```dart
class TokenBucketRateLimiter {
  final int _bucketCapacity;
  final int _refillRate; // Tokens per second
  final Duration _refillInterval;
  
  int _currentTokens;
  DateTime _lastRefill;

  TokenBucketRateLimiter({
    required int bucketCapacity,
    required int refillRate,
    Duration refillInterval = const Duration(seconds: 1),
  }) : _bucketCapacity = bucketCapacity,
       _refillRate = refillRate,
       _refillInterval = refillInterval,
       _currentTokens = bucketCapacity,
       _lastRefill = DateTime.now();

  bool tryConsume({int tokens = 1}) {
    _refillTokens();
    
    if (_currentTokens >= tokens) {
      _currentTokens -= tokens;
      return true;
    }
    
    return false;
  }

  void _refillTokens() {
    final now = DateTime.now();
    final timePassed = now.difference(_lastRefill);
    
    if (timePassed >= _refillInterval) {
      final periodsElapsed = timePassed.inMilliseconds ~/ _refillInterval.inMilliseconds;
      final tokensToAdd = periodsElapsed * _refillRate;
      
      _currentTokens = math.min(_bucketCapacity, _currentTokens + tokensToAdd);
      _lastRefill = now;
    }
  }

  int get availableTokens => _currentTokens;
  int get bucketCapacity => _bucketCapacity;
}

class TokenBucketRateLimiterService {
  final Map<String, TokenBucketRateLimiter> _buckets = {};

  ResiliencePipeline createPipeline({
    required String bucketKey,
    required int bucketCapacity,
    required int refillRate,
  }) {
    final bucket = _buckets.putIfAbsent(
      bucketKey,
      () => TokenBucketRateLimiter(
        bucketCapacity: bucketCapacity,
        refillRate: refillRate,
      ),
    );

    return ResiliencePipelineBuilder()
        .addRateLimiter(RateLimiterStrategyOptions(
          permitLimit: bucketCapacity,
          window: Duration(seconds: 1),
          // Custom logic handled by token bucket
        ))
        .build();
  }

  Future<T> execute<T>(
    String bucketKey,
    Future<T> Function() operation, {
    int tokenCost = 1,
  }) async {
    final bucket = _buckets[bucketKey];
    if (bucket == null) {
      throw Exception('Rate limiter bucket not found: $bucketKey');
    }

    if (!bucket.tryConsume(tokens: tokenCost)) {
      logger.warning('Token bucket rate limit exceeded for bucket: $bucketKey');
      throw RateLimiterRejectedException('Rate limit exceeded');
    }

    return await operation();
  }
}
```

### Resource-Based Rate Limiting
Different limits for different types of operations:

```dart
class ResourceBasedRateLimiterService {
  final Map<ResourceType, ResiliencePipeline> _resourcePipelines = {};

  ResourceBasedRateLimiterService() {
    _initializePipelines();
  }

  void _initializePipelines() {
    _resourcePipelines[ResourceType.database] = _createPipeline(
      permitLimit: 50,  // Conservative limit for database
      window: Duration(seconds: 1),
      queueLimit: 20,
    );

    _resourcePipelines[ResourceType.externalApi] = _createPipeline(
      permitLimit: 30,  // Respect third-party API limits
      window: Duration(seconds: 1),
      queueLimit: 10,
    );

    _resourcePipelines[ResourceType.fileSystem] = _createPipeline(
      permitLimit: 100, // Higher limit for file operations
      window: Duration(seconds: 1),
      queueLimit: 50,
    );

    _resourcePipelines[ResourceType.compute] = _createPipeline(
      permitLimit: 20,  // Lower limit for CPU-intensive operations
      window: Duration(seconds: 1),
      queueLimit: 5,
    );
  }

  ResiliencePipeline _createPipeline({
    required int permitLimit,
    required Duration window,
    required int queueLimit,
  }) {
    return ResiliencePipelineBuilder()
        .addRateLimiter(RateLimiterStrategyOptions(
          permitLimit: permitLimit,
          window: window,
          queueLimit: queueLimit,
          onRejected: _onResourceRateLimitRejected,
          onQueued: _onResourceRequestQueued,
        ))
        .build();
  }

  Future<T> execute<T>(
    ResourceType resourceType,
    Future<T> Function(ResilienceContext) operation,
  ) async {
    final pipeline = _resourcePipelines[resourceType];
    if (pipeline == null) {
      throw Exception('No rate limiter configured for resource: $resourceType');
    }

    final context = ResilienceContext();
    context.setProperty('resourceType', resourceType.toString());

    return await pipeline.execute(operation, context: context);
  }

  Future<void> _onResourceRateLimitRejected(
    OnRateLimiterRejectedArguments args,
  ) async {
    final resourceType = args.context.getProperty<String>('resourceType');
    
    logger.warning('Rate limit exceeded for resource: $resourceType');
    metrics.incrementCounter('resource_rate_limit_exceeded', tags: {
      'resource_type': resourceType ?? 'unknown',
    });
  }

  Future<void> _onResourceRequestQueued(
    OnRateLimiterQueuedArguments args,
  ) async {
    final resourceType = args.context.getProperty<String>('resourceType');
    
    logger.debug('Request queued for resource: $resourceType');
    metrics.incrementCounter('resource_requests_queued', tags: {
      'resource_type': resourceType ?? 'unknown',
    });
  }
}

enum ResourceType {
  database,
  externalApi,
  fileSystem,
  compute,
}
```

## Real-World Examples

### API Gateway Rate Limiting
```dart
class ApiGatewayRateLimiter {
  final Map<String, ResiliencePipeline> _endpointPipelines = {};
  final Map<String, EndpointConfig> _endpointConfigs;

  ApiGatewayRateLimiter(this._endpointConfigs) {
    _initializePipelines();
  }

  void _initializePipelines() {
    for (final entry in _endpointConfigs.entries) {
      final endpoint = entry.key;
      final config = entry.value;

      _endpointPipelines[endpoint] = ResiliencePipelineBuilder()
          .addRateLimiter(RateLimiterStrategyOptions(
            permitLimit: config.rateLimit,
            window: config.window,
            queueLimit: config.queueLimit,
            onRejected: (args) => _onEndpointRateLimitRejected(endpoint, args),
          ))
          .build();
    }
  }

  Future<Response> handleRequest(Request request) async {
    final endpoint = _extractEndpoint(request);
    final pipeline = _endpointPipelines[endpoint];

    if (pipeline == null) {
      return Response.notFound('Endpoint not found');
    }

    final context = ResilienceContext();
    context.setProperty('endpoint', endpoint);
    context.setProperty('clientIp', request.clientIp);
    context.setProperty('userAgent', request.headers['user-agent']);

    try {
      return await pipeline.execute((ctx) async {
        return await _processRequest(request);
      }, context: context);
    } on RateLimiterRejectedException {
      return Response(
        statusCode: 429,
        body: {'error': 'Rate limit exceeded', 'retryAfter': '60'},
        headers: {'Retry-After': '60'},
      );
    }
  }

  String _extractEndpoint(Request request) {
    // Extract endpoint pattern from request path
    return request.path.split('/').take(3).join('/');
  }

  Future<Response> _processRequest(Request request) async {
    // Actual request processing logic
    return Response.ok({'message': 'Request processed successfully'});
  }

  Future<void> _onEndpointRateLimitRejected(
    String endpoint,
    OnRateLimiterRejectedArguments args,
  ) async {
    final clientIp = args.context.getProperty<String>('clientIp');
    final userAgent = args.context.getProperty<String>('userAgent');

    logger.warning(
      'Rate limit exceeded for endpoint: $endpoint, client: $clientIp, UA: $userAgent',
    );

    metrics.incrementCounter('api_rate_limit_exceeded', tags: {
      'endpoint': endpoint,
      'client_ip': clientIp ?? 'unknown',
    });

    // Could trigger additional security measures
    if (clientIp != null) {
      await securityService.reportSuspiciousActivity(clientIp);
    }
  }
}

class EndpointConfig {
  final int rateLimit;
  final Duration window;
  final int queueLimit;

  EndpointConfig({
    required this.rateLimit,
    required this.window,
    required this.queueLimit,
  });
}
```

### Background Job Rate Limiting
```dart
class JobProcessorService {
  final Map<JobPriority, ResiliencePipeline> _priorityPipelines = {};
  final JobQueue _jobQueue;

  JobProcessorService(this._jobQueue) {
    _initializePriorityPipelines();
  }

  void _initializePriorityPipelines() {
    _priorityPipelines[JobPriority.critical] = _createPipeline(
      permitLimit: 50,   // High throughput for critical jobs
      window: Duration(seconds: 1),
      queueLimit: 100,
    );

    _priorityPipelines[JobPriority.high] = _createPipeline(
      permitLimit: 30,   // Medium throughput
      window: Duration(seconds: 1),
      queueLimit: 50,
    );

    _priorityPipelines[JobPriority.normal] = _createPipeline(
      permitLimit: 20,   // Normal throughput
      window: Duration(seconds: 1),
      queueLimit: 30,
    );

    _priorityPipelines[JobPriority.low] = _createPipeline(
      permitLimit: 10,   // Lower throughput for background tasks
      window: Duration(seconds: 1),
      queueLimit: 20,
    );
  }

  ResiliencePipeline _createPipeline({
    required int permitLimit,
    required Duration window,
    required int queueLimit,
  }) {
    return ResiliencePipelineBuilder()
        .addRateLimiter(RateLimiterStrategyOptions(
          permitLimit: permitLimit,
          window: window,
          queueLimit: queueLimit,
          onRejected: _onJobRateLimitRejected,
          onQueued: _onJobQueued,
        ))
        .build();
  }

  Future<void> processJobs() async {
    while (true) {
      final jobs = await _jobQueue.getNextBatch();
      
      if (jobs.isEmpty) {
        await Future.delayed(Duration(seconds: 1));
        continue;
      }

      // Group jobs by priority
      final jobsByPriority = <JobPriority, List<Job>>{};
      for (final job in jobs) {
        jobsByPriority.putIfAbsent(job.priority, () => []).add(job);
      }

      // Process jobs by priority
      for (final priority in JobPriority.values) {
        final priorityJobs = jobsByPriority[priority] ?? [];
        if (priorityJobs.isNotEmpty) {
          await _processJobsByPriority(priority, priorityJobs);
        }
      }
    }
  }

  Future<void> _processJobsByPriority(
    JobPriority priority,
    List<Job> jobs,
  ) async {
    final pipeline = _priorityPipelines[priority]!;

    final futures = jobs.map((job) async {
      final context = ResilienceContext();
      context.setProperty('jobId', job.id);
      context.setProperty('jobType', job.type);
      context.setProperty('priority', priority.toString());

      try {
        await pipeline.execute((ctx) async {
          await _processJob(job);
        }, context: context);
      } on RateLimiterRejectedException {
        // Re-queue the job for later processing
        await _jobQueue.requeue(job, delay: Duration(seconds: 30));
        logger.info('Job ${job.id} re-queued due to rate limit');
      }
    });

    await Future.wait(futures);
  }

  Future<void> _processJob(Job job) async {
    logger.info('Processing job: ${job.id} (${job.type})');
    
    // Simulate job processing
    await Future.delayed(Duration(milliseconds: 100));
    
    // Mark job as completed
    await _jobQueue.markCompleted(job.id);
  }

  Future<void> _onJobRateLimitRejected(
    OnRateLimiterRejectedArguments args,
  ) async {
    final jobId = args.context.getProperty<String>('jobId');
    final priority = args.context.getProperty<String>('priority');
    
    logger.warning('Job rate limit exceeded: $jobId (priority: $priority)');
    
    metrics.incrementCounter('job_rate_limit_exceeded', tags: {
      'job_id': jobId ?? 'unknown',
      'priority': priority ?? 'unknown',
    });
  }

  Future<void> _onJobQueued(OnRateLimiterQueuedArguments args) async {
    final jobId = args.context.getProperty<String>('jobId');
    final priority = args.context.getProperty<String>('priority');
    
    logger.debug('Job queued: $jobId (priority: $priority)');
    
    metrics.incrementCounter('jobs_queued', tags: {
      'priority': priority ?? 'unknown',
    });
  }
}

enum JobPriority { critical, high, normal, low }

class Job {
  final String id;
  final String type;
  final JobPriority priority;
  final Map<String, dynamic> data;

  Job({
    required this.id,
    required this.type,
    required this.priority,
    required this.data,
  });
}
```

### Database Connection Pool Rate Limiting
```dart
class DatabaseConnectionPoolService {
  final int _maxConnections;
  final Duration _connectionTimeout;
  late final ResiliencePipeline _connectionPipeline;
  late final ConnectionPool _connectionPool;

  DatabaseConnectionPoolService({
    required int maxConnections,
    Duration connectionTimeout = const Duration(seconds: 30),
  }) : _maxConnections = maxConnections,
       _connectionTimeout = connectionTimeout {
    _initializeConnectionPool();
    _initializeRateLimiter();
  }

  void _initializeConnectionPool() {
    _connectionPool = ConnectionPool(
      maxConnections: _maxConnections,
      connectionTimeout: _connectionTimeout,
    );
  }

  void _initializeRateLimiter() {
    _connectionPipeline = ResiliencePipelineBuilder()
        .addRateLimiter(RateLimiterStrategyOptions(
          permitLimit: _maxConnections,
          window: Duration(seconds: 1),
          queueLimit: _maxConnections * 2, // Allow queuing
          onRejected: _onConnectionRateLimitRejected,
          onQueued: _onConnectionQueued,
        ))
        .build();
  }

  Future<T> executeQuery<T>(
    String query,
    List<dynamic> parameters,
    T Function(ResultSet) mapper,
  ) async {
    final context = ResilienceContext();
    context.setProperty('query', query);
    context.setProperty('parameterCount', parameters.length);

    return await _connectionPipeline.execute((ctx) async {
      final connection = await _connectionPool.acquire();
      try {
        final resultSet = await connection.query(query, parameters);
        return mapper(resultSet);
      } finally {
        _connectionPool.release(connection);
      }
    }, context: context);
  }

  Future<void> executeTransaction(
    Future<void> Function(DatabaseTransaction) transaction,
  ) async {
    final context = ResilienceContext();
    context.setProperty('operation', 'transaction');

    await _connectionPipeline.execute((ctx) async {
      final connection = await _connectionPool.acquire();
      try {
        final tx = await connection.beginTransaction();
        try {
          await transaction(tx);
          await tx.commit();
        } catch (e) {
          await tx.rollback();
          rethrow;
        }
      } finally {
        _connectionPool.release(connection);
      }
    }, context: context);
  }

  Future<void> _onConnectionRateLimitRejected(
    OnRateLimiterRejectedArguments args,
  ) async {
    final query = args.context.getProperty<String>('query');
    
    logger.warning('Database connection rate limit exceeded for query: $query');
    
    metrics.incrementCounter('db_connection_rate_limit_exceeded', tags: {
      'operation': args.context.getProperty<String>('operation') ?? 'query',
    });
  }

  Future<void> _onConnectionQueued(OnRateLimiterQueuedArguments args) async {
    final operation = args.context.getProperty<String>('operation') ?? 'query';
    
    logger.debug('Database operation queued: $operation');
    
    metrics.incrementCounter('db_operations_queued', tags: {
      'operation': operation,
    });
  }

  Future<void> dispose() async {
    await _connectionPool.close();
  }
}
```

## Testing Rate Limiter Strategies

### Unit Testing Rate Limiting
```dart
import 'package:test/test.dart';
import 'package:polly_dart/polly_dart.dart';

void main() {
  group('Rate Limiter Strategy Tests', () {
    test('should reject requests when limit exceeded', () async {
      final pipeline = ResiliencePipelineBuilder()
          .addRateLimiter(RateLimiterStrategyOptions(
            permitLimit: 2,
            window: Duration(seconds: 1),
          ))
          .build();

      // First two requests should succeed
      await pipeline.execute((context) async => 'request1');
      await pipeline.execute((context) async => 'request2');

      // Third request should be rejected
      expect(
        () => pipeline.execute((context) async => 'request3'),
        throwsA(isA<RateLimiterRejectedException>()),
      );
    });

    test('should queue requests when queueLimit is set', () async {
      var executionOrder = <String>[];
      final pipeline = ResiliencePipelineBuilder()
          .addRateLimiter(RateLimiterStrategyOptions(
            permitLimit: 1,
            window: Duration(seconds: 1),
            queueLimit: 2,
          ))
          .build();

      // Start multiple requests
      final futures = [
        pipeline.execute((context) async {
          await Future.delayed(Duration(milliseconds: 100));
          executionOrder.add('request1');
          return 'request1';
        }),
        pipeline.execute((context) async {
          executionOrder.add('request2');
          return 'request2';
        }),
        pipeline.execute((context) async {
          executionOrder.add('request3');
          return 'request3';
        }),
      ];

      await Future.wait(futures);

      // Requests should execute in order
      expect(executionOrder, equals(['request1', 'request2', 'request3']));
    });

    test('should call callbacks correctly', () async {
      var rejectedCalled = false;
      var queuedCalled = false;
      
      final pipeline = ResiliencePipelineBuilder()
          .addRateLimiter(RateLimiterStrategyOptions(
            permitLimit: 1,
            window: Duration(seconds: 1),
            queueLimit: 1,
            onRejected: (args) async {
              rejectedCalled = true;
            },
            onQueued: (args) async {
              queuedCalled = true;
            },
          ))
          .build();

      // First request succeeds
      await pipeline.execute((context) async => 'request1');

      // Second request gets queued
      final future2 = pipeline.execute((context) async => 'request2');

      // Third request gets rejected
      expect(
        () => pipeline.execute((context) async => 'request3'),
        throwsA(isA<RateLimiterRejectedException>()),
      );

      await future2;

      expect(queuedCalled, isTrue);
      expect(rejectedCalled, isTrue);
    });

    test('should replenish permits over time', () async {
      final pipeline = ResiliencePipelineBuilder()
          .addRateLimiter(RateLimiterStrategyOptions(
            permitLimit: 1,
            window: Duration(milliseconds: 100),
            autoReplenishment: true,
          ))
          .build();

      // First request succeeds
      await pipeline.execute((context) async => 'request1');

      // Second request immediately should fail
      expect(
        () => pipeline.execute((context) async => 'request2'),
        throwsA(isA<RateLimiterRejectedException>()),
      );

      // Wait for permit replenishment
      await Future.delayed(Duration(milliseconds: 150));

      // Third request should succeed after replenishment
      final result = await pipeline.execute((context) async => 'request3');
      expect(result, equals('request3'));
    });
  });

  group('Rate Limiter Performance Tests', () {
    test('should maintain consistent throughput', () async {
      final pipeline = ResiliencePipelineBuilder()
          .addRateLimiter(RateLimiterStrategyOptions(
            permitLimit: 10,
            window: Duration(seconds: 1),
            queueLimit: 20,
          ))
          .build();

      final stopwatch = Stopwatch()..start();
      final completedRequests = <String>[];

      // Launch many requests
      final futures = List.generate(25, (index) async {
        try {
          final result = await pipeline.execute((context) async {
            await Future.delayed(Duration(milliseconds: 50));
            return 'request$index';
          });
          completedRequests.add(result);
        } on RateLimiterRejectedException {
          // Some requests may be rejected
        }
      });

      await Future.wait(futures);
      stopwatch.stop();

      // Should have processed requests within reasonable time
      expect(completedRequests.length, greaterThan(15));
      expect(stopwatch.elapsedMilliseconds, lessThan(5000));
    });
  });
}
```

## Best Practices

### ✅ Do

**Set Appropriate Limits**
```dart
// ✅ Good: Based on actual capacity and requirements
.addRateLimiter(RateLimiterStrategyOptions(
  permitLimit: 100, // Based on measured system capacity
  window: Duration(seconds: 1),
  queueLimit: 50,   // Reasonable queue size
));
```

**Monitor Rate Limiting**
```dart
// ✅ Good: Track rate limiting effectiveness
.addRateLimiter(RateLimiterStrategyOptions(
  onRejected: (args) async {
    metrics.incrementCounter('rate_limit_rejections');
    logger.warning('Rate limit exceeded');
  },
));
```

**Use Queuing for User-Facing Operations**
```dart
// ✅ Good: Queue user requests rather than reject
.addRateLimiter(RateLimiterStrategyOptions(
  permitLimit: 20,
  window: Duration(seconds: 1),
  queueLimit: 40, // Allow queuing for better UX
));
```

### ❌ Don't

**Set Limits Too Low**
```dart
// ❌ Bad: Overly restrictive limits
.addRateLimiter(RateLimiterStrategyOptions(
  permitLimit: 1,     // Too restrictive
  window: Duration(minutes: 1),
  queueLimit: 0,      // No queuing
));
```

**Ignore Rate Limit Exceptions**
```dart
// ❌ Bad: Swallowing rate limit exceptions
try {
  await pipeline.execute(
    operation,
    context: ResilienceContext(operationKey: 'my-operation'),
  );
} catch (RateLimiterRejectedException) {
  // Ignoring without proper handling
}
```

**Use Only Rate Limiting**
```dart
// ❌ Bad: Rate limiting without other resilience strategies
.addRateLimiter(RateLimiterStrategyOptions(...)) // Only rate limiting
```

## Performance Considerations

- **Memory Usage**: Rate limiters maintain internal state for tracking
- **CPU Overhead**: Permit calculation and queue management
- **Latency Impact**: Queuing adds latency to requests
- **Scalability**: Consider distributed rate limiting for multiple instances

## Common Patterns

### Graceful Degradation
```dart
try {
  return await rateLimitedPipeline.execute(
    expensiveOperation,
    context: ResilienceContext(operationKey: 'expensive-operation'),
  );
} on RateLimiterRejectedException {
  return await fallbackPipeline.execute(
    cheaperOperation,
    context: ResilienceContext(operationKey: 'cheaper-operation'),
  );
}
```

### Priority-Based Processing
```dart
final pipeline = priority == Priority.high 
    ? highPriorityPipeline 
    : normalPriorityPipeline;
```

## Next Steps

Rate limiting provides essential traffic control for your applications:

1. **[Combine Strategies](../advanced/combining-strategies)** - Build comprehensive resilience pipelines
2. **[Monitor and Observe](../advanced/monitoring)** - Track rate limiting effectiveness
3. **[Deploy at Scale](../advanced/deployment)** - Implement distributed rate limiting

Rate limiting is your first line of defense against overload - use it wisely to protect your resources while maintaining good user experience.
