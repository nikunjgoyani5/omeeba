bool isLiveMode = false;

String baseUrlDev = 'https://staging.omeeba.co.in/api/v1/';
String baseUrlLive = 'https://omeeba.co.in/api/v1/';

String baseUrl = isLiveMode ? baseUrlLive : baseUrlDev;

String socketUrlDev = 'https://staging.omeeba.co.in';
String socketUrlLive = 'https://omeeba.co.in';

String socketUrl = isLiveMode ? socketUrlLive : socketUrlDev;

const String oneSignalAppId = 'fbfeabb6-d6e5-4f60-be5f-44156d6f1e72';

String saansTrial = 'saansTrial';


String formatCount(int count) {
  if (count < 1000) return '$count';

  if (count < 1000000) {
    double value = count / 1000;
    return '${value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1)}K';
  }

  double value = count / 1000000;
  return '${value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1)}M';
}