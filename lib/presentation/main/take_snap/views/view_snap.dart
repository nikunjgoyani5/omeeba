import 'package:cached_network_image/cached_network_image.dart';

import '../../../../core/utils/exports.dart';

class ViewSnapScreen extends StatelessWidget {
  const ViewSnapScreen({super.key, required this.image});

  final String image;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          /// Image Viewer
          Center(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: CachedNetworkImage(
                imageUrl: image,
                width: Get.width,
                height: Get.height,
                fit: BoxFit.contain,
                placeholder: (context, url) => const Center(child: CircularProgressIndicator(color: Colors.white)),
                errorWidget: (context, url, error) => Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.broken_image_outlined, color: Colors.white54, size: 80),
                    SizedBox(height: 12),
                    Text("Unable to load image", style: TextStyle(color: Colors.white54)),
                  ],
                ),
              ),
            ),
          ),

          /// Close Button
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            child: GestureDetector(
              onTap: () => Get.back(),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.5), shape: BoxShape.circle),
                child: const Icon(Icons.close, color: Colors.black, size: 24),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
