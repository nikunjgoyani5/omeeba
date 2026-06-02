import 'package:omeeba_new/core/utils/exports.dart';
import 'package:omeeba_new/presentation/main/create_post/controller/create_post_controller.dart';

class PollDurationPicker extends StatefulWidget {
  final CreatePostController controller;
  final int initialDays;
  final int initialHours;
  final int initialMinutes;

  const PollDurationPicker({
    super.key,
    required this.controller,
    required this.initialDays,
    required this.initialHours,
    required this.initialMinutes,
  });

  @override
  State<PollDurationPicker> createState() => _PollDurationPickerState();
}

class _PollDurationPickerState extends State<PollDurationPicker> {
  late ScrollController _daysController;
  late ScrollController _hoursController;
  late ScrollController _minutesController;

  int selectedDays = 0;
  int selectedHours = 0;
  int selectedMinutes = 0;

  final double itemHeight = 50.0;

  @override
  void initState() {
    super.initState();
    selectedDays = widget.initialDays;
    selectedHours = widget.initialHours;
    selectedMinutes = widget.initialMinutes;

    _daysController = ScrollController();
    _hoursController = ScrollController();
    _minutesController = ScrollController();

    // Add listeners to track scroll position
    _daysController.addListener(_updateDaysSelection);
    _hoursController.addListener(_updateHoursSelection);
    _minutesController.addListener(_updateMinutesSelection);

    // Scroll to initial position after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToItem(_daysController, selectedDays);
      _scrollToItem(_hoursController, selectedHours);
      _scrollToItem(_minutesController, selectedMinutes);
    });
  }

  void _updateDaysSelection() {
    if (_daysController.hasClients) {
      final index = (_daysController.offset / itemHeight).round().clamp(0, 31);
      if (index != selectedDays) {
        setState(() {
          selectedDays = index;
        });
      }
    }
  }

  void _updateHoursSelection() {
    if (_hoursController.hasClients) {
      final index = (_hoursController.offset / itemHeight).round().clamp(0, 23);
      if (index != selectedHours) {
        setState(() {
          selectedHours = index;
        });
      }
    }
  }

  void _updateMinutesSelection() {
    if (_minutesController.hasClients) {
      final index = (_minutesController.offset / itemHeight).round().clamp(0, 59);
      if (index != selectedMinutes) {
        setState(() {
          selectedMinutes = index;
        });
      }
    }
  }

  void _scrollToItem(ScrollController controller, int index) {
    if (controller.hasClients) {
      controller.jumpTo(index * itemHeight);
    }
  }

  @override
  void dispose() {
    _daysController.dispose();
    _hoursController.dispose();
    _minutesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: Get.height * 0.5,
      decoration: BoxDecoration(
        color: AppColors.whiteFFFFFF,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(20.r), topRight: Radius.circular(20.r)),
      ),
      child: Column(
        children: [
          Container(
            margin: EdgeInsets.only(top: 12.h),
            height: 5.w,
            width: 55.w,
            decoration: BoxDecoration(color: AppColors.grayEDF1F4, borderRadius: BorderRadius.circular(50)),
          ),

          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
            decoration: BoxDecoration(
              // border: Border(bottom: BorderSide(color: AppColors.grayEAEAEA, width: 1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [Text('Set Duration', style: TextStyles.semiBold(20.sp, fontColor: AppColors.black2F3039))],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 10.h),

              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12.sp),
                border: Border.all(color: AppColors.grayEDF1F4),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,

                children: [
                  Expanded(
                    child: Text(
                      'Day',
                      style: TextStyles.semiBold(16.sp, fontColor: AppColors.black2F3039),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  Expanded(
                    child: Text(
                      'Hours',
                      style: TextStyles.semiBold(16.sp, fontColor: AppColors.black2F3039),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Minutes',
                      style: TextStyles.semiBold(16.sp, fontColor: AppColors.black2F3039),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Picker
          Expanded(
            child: Row(
              children: [
                // Days
                Expanded(
                  child: ListView.builder(
                    controller: _daysController,

                    // itemExtent: itemHeight,
                    itemCount: 34, // 0-31 days
                    itemBuilder: (context, index) {
                      final isSelected = index == selectedDays;
                      return GestureDetector(
                        onTap: () {
                          _scrollToItem(_daysController, index);
                          setState(() {
                            selectedDays = index;
                          });
                        },
                        child: Container(
                          alignment: Alignment.center,
                          height: itemHeight,
                          child: Container(
                            alignment: Alignment.center,
                            height: 28,
                            width: 70,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              color: isSelected ? AppColors.grayEDF1F4 : Colors.transparent,
                            ),
                            child: Text(
                              index > 30 ? "":index.toString(),
                              style: TextStyles.medium(
                                20.sp,
                                fontColor: isSelected ? AppColors.black000000 : AppColors.gray8C9499,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                Expanded(
                  child: ListView.builder(

                    controller: _hoursController,
                    itemExtent: itemHeight,
                    itemCount: 27, // 0-23 hours
                    itemBuilder: (context, index) {
                      final isSelected = index == selectedHours;
                      return GestureDetector(
                        onTap: () {
                          _scrollToItem(_hoursController, index);
                          setState(() {
                            selectedHours = index;
                          });
                        },
                        child: Container(
                          alignment: Alignment.center,
                          height: itemHeight,
                          child: Container(
                            alignment: Alignment.center,
                            height: 28,
                            width: 70,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              color: isSelected ? AppColors.grayEDF1F4 : Colors.transparent,
                            ),
                            child: Text(
                              index > 23 ? "":index.toString(),
                              style: TextStyles.medium(
                                20.sp,
                                fontColor: isSelected ? AppColors.black000000 : AppColors.gray8C9499,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // Minutes
                Expanded(
                  child: ListView.builder(
                    controller: _minutesController,
                    itemExtent: itemHeight,
                    itemCount: 63, // 0-59 minutes
                    itemBuilder: (context, index) {
                      final isSelected = index == selectedMinutes;
                      return GestureDetector(
                        onTap: () {
                          _scrollToItem(_minutesController, index);
                          setState(() {
                            selectedMinutes = index;
                          });
                        },
                        child: Container(
                          alignment: Alignment.center,
                          height: itemHeight,
                          child: Container(
                            alignment: Alignment.center,
                            height: 28,
                            width: 70,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              color: isSelected ? AppColors.grayEDF1F4 : Colors.transparent,
                            ),
                            child: Text(
                              index > 59 ? "":index.toString(),
                              style: TextStyles.medium(
                                20.sp,
                                fontColor: isSelected ? AppColors.black000000 : AppColors.gray8C9499,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Gap(5.h),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: CommonButton(
              text: 'Done',
              onPressed: () {
                widget.controller.setPollDuration(selectedDays, selectedHours, selectedMinutes);
                Get.back();
              },
            ),
          ),

          Gap(15.h),
        ],
      ),
    );
  }
}
