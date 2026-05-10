import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:haptext_api/bloc/auth/cubit/auth_cubit.dart';
import 'package:haptext_api/bloc/profile/cubit/profile_cubit.dart';
import 'package:haptext_api/common/theme/custom_theme_extension.dart';
import 'package:haptext_api/exports.dart';
import 'package:haptext_api/utils/extensions.dart';
import 'package:haptext_api/utils/session_manager.dart';
import 'package:haptext_api/views/Bottom_Nav/exports.dart';

class EditProfile extends StatefulWidget {
  const EditProfile({Key? key}) : super(key: key);

  @override
  State<EditProfile> createState() => _EditProfileState();
}

class _EditProfileState extends State<EditProfile> {
  final firstController = TextEditingController();
  final lastNameController = TextEditingController();
  final birthdayController = TextEditingController();
  final ocupationController = TextEditingController();
  final heightController = TextEditingController();
  final weightController = TextEditingController();
  final ethnicityController = TextEditingController();
  final relationshipStatusController = TextEditingController();
  final locationController = TextEditingController();
  final biographyController = TextEditingController();
  File? profilePhoto;
  File? coverPhoto;
  final formkey = GlobalKey<FormState>();
  @override
  void initState() {
    super.initState();
    final readAuth = context.read<AuthCubit>();
    firstController.text = readAuth.useInfo.profile?.firstName ?? "";
    lastNameController.text = readAuth.useInfo.profile?.lastName ?? "";
    biographyController.text = readAuth.useInfo.profile?.bio ?? "";
    ocupationController.text = readAuth.useInfo.profile?.occupation ?? "";
    birthdayController.text = readAuth.useInfo.profile?.birthDate ?? "";
    heightController.text = "${readAuth.useInfo.profile?.height ?? ""}";
    weightController.text = "${readAuth.useInfo.profile?.weight ?? ""}";
    ethnicityController.text = readAuth.useInfo.profile?.ethnicity ?? "";
    relationshipStatusController.text =
        readAuth.useInfo.profile?.relationshipStatus ?? "";
    locationController.text = readAuth.useInfo.profile?.location ?? "";
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final watchProfile = context.watch<ProfileCubit>();
    return BlocListener<ProfileCubit, ProfileState>(
      listener: (context, state) {
        if (state is ProfileUpdated) {
          final shouldWarn = state.warnings != null && state.warnings!.isNotEmpty;
          if (state.profile != null) {
            final auth = context.read<AuthCubit>();
            auth.useInfo.profile = state.profile;
            SessionManager.storeUser(auth.useInfo);
          }
          Future.microtask(() {
            if (!context.mounted) return;
            context.pop();
            if (shouldWarn) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                ToastMessage.showWarningToast(
                    message:
                        'Image upload blocked. Fix Storage policies, then try again.');
              });
            }
          });
        }
      },
      child: Opacity(
        opacity: watchProfile.state is ProfileLoading ? 0.5 : 1.0,
        child: AbsorbPointer(
          absorbing: watchProfile.state is ProfileLoading,
          child: Scaffold(
              appBar: AppBar(
                  forceMaterialTransparency: true,
                  iconTheme: const IconThemeData(),
                  title: const AppText(
                      text: 'Edit Profile', fontSize: 20, color: Colors.white),
                  centerTitle: true,
                  actions: const [],
                  elevation: 0),
              body: Form(
                  key: formkey,
                  child: Column(children: [
                    const SizedBox(height: 10),
                    PicsChange(
                      currentProfileUrl: context
                          .read<AuthCubit>()
                          .useInfo
                          .profile
                          ?.profilePicture,
                      currentCoverUrl: context
                          .read<AuthCubit>()
                          .useInfo
                          .profile
                          ?.coverPicture,
                      onchangeProfile: (profile) {
                        log("message$profile");
                        setState(() {
                          profilePhoto = profile;
                        });
                      },
                      onchangeCoverPhoto: (profile) {
                        setState(() {
                          coverPhoto = profile;
                        });
                      },
                    ),
                    40.verticalSpace,
                    Expanded(
                        child: ListView(
                            padding: EdgeInsets.symmetric(
                                horizontal: size.width * 0.04),
                            children: [
                          InputField(
                              title: 'First Name',
                              hintText: 'Enter first name',
                              validator: (p) =>
                                  p?.validateName(field: "First Name"),
                              controller: firstController),
                          20.verticalSpace,
                          InputField(
                              title: 'Lat Name',
                              validator: (p) =>
                                  p?.validateName(field: "Last Name"),
                              hintText: 'Enter Last name',
                              controller: lastNameController),
                          20.verticalSpace,
                          InputField(
                              title: 'Biography',
                              hintText: 'Enter bio',
                              maxLines: 5,
                              validator: (p) =>
                                  p?.validateAnyField(field: "Biography"),
                              controller: biographyController),
                          20.verticalSpace,
                          InputField(
                              title: 'Birthday',
                              validator: (p) => p?.validateDob(),
                              hintText: 'YYYY/MM/DD',
                              keyboardType: TextInputType.datetime,
                              controller: birthdayController),
                          20.verticalSpace,
                          InputField(
                              title: 'Occupation',
                              validator: (p) =>
                                  p?.validateAnyField(field: "Occupation"),
                              hintText: 'occupation',
                              controller: ocupationController),
                          20.verticalSpace,
                          InputField(
                              title: 'Height',
                              hintText: '0.00',
                              keyboardType: TextInputType.number,
                              validator: (p) =>
                                  p?.validateAnyField(field: "Height"),
                              controller: heightController),
                          20.verticalSpace,
                          InputField(
                              title: 'Weight',
                              keyboardType: TextInputType.number,
                              validator: (p) =>
                                  p?.validateAnyField(field: "Weight"),
                              hintText: '0.00',
                              controller: weightController),
                          20.verticalSpace,
                          InputField(
                              title: 'Ethnicity',
                              isReadOnly: true,
                              onTap: () {
                                showModalBottomSheet(
                                    context: context,
                                    backgroundColor: Colors.transparent,
                                    isScrollControlled: true,
                                    builder: (_) {
                                      return EthicityModalSheet(
                                          ethicity: (value) {
                                        setState(() {
                                          log("message$value");
                                          ethnicityController.text = value;
                                        });
                                      });
                                    });
                              },
                              validator: (p) =>
                                  p?.validateAnyField(field: "Ethnicity"),
                              hintText: 'Christianity/Islamic',
                              controller: ethnicityController),
                          20.verticalSpace,
                          InputField(
                              title: 'Relationship status',
                              isReadOnly: true,
                              onTap: () {
                                showModalBottomSheet(
                                    context: context,
                                    backgroundColor: Colors.transparent,
                                    isScrollControlled: true,
                                    builder: (_) {
                                      return RelationshipModalSheet(
                                          status: (String value) {
                                        log("message$value");
                                        relationshipStatusController.text =
                                            value;
                                      });
                                    });
                              },
                              validator: (p) => p?.validateAnyField(
                                  field: "Relationship status"),
                              hintText: 'Single/Married/Divorced...',
                              controller: relationshipStatusController),
                          20.verticalSpace,
                          InputField(
                              title: 'Location',
                              validator: (p) =>
                                  p?.validateAnyField(field: "Address"),
                              hintText: 'lagos , Nigeria',
                              controller: locationController),
                          60.verticalSpace,
                          Appbutton(
                              isLoading: watchProfile.state is ProfileLoading,
                              gradient: true,
                              onTap: () {
                                final user = context.read<AuthCubit>().useInfo;
                                // if (formkey.currentState?.validate() ?? false) {
                                context.read<ProfileCubit>().createProfile(
                                    userId: user.id ?? '',
                                    updateProfile:
                                        user.profile?.firstName != null,
                                    birthDate: birthdayController.text,
                                    ethnicity: ethnicityController.text,
                                    relationshipStatus:
                                        relationshipStatusController.text,
                                    firstName: firstController.text,
                                    lastName: lastNameController.text,
                                    bio: biographyController.text,
                                    occupation: ocupationController.text,
                                    profilePicture: profilePhoto,
                                    coverPicture: coverPhoto,
                                    location: locationController.text,
                                    height: heightController.text,
                                    weight: weightController.text);
                                // }
                              },
                              label: 'Save'),
                          60.verticalSpace
                        ]))
                  ]))),
        ),
      ),
    );
  }
}

class EthicityModalSheet extends StatelessWidget {
  const EthicityModalSheet({super.key, required this.ethicity});
  final Function(String value) ethicity;
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Container(
      width: size.width,
      decoration: BoxDecoration(
        color: context.theme.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: EdgeInsets.all(size.width * 0.06),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const AppText(
              text: "Select Ethnicity",
              fontSize: 20,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            const SizedBox(height: 24),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: items.length,
                separatorBuilder: (context, index) =>
                    Divider(color: Colors.white.withOpacity(0.05)),
                itemBuilder: (context, index) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: AppText(
                    text: items[index].capitalizeFirstChar(),
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                  trailing: const Icon(Icons.chevron_right,
                      color: Colors.white24, size: 20),
                  onTap: () {
                    ethicity(items[index]);
                    Navigator.pop(context);
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  static List<String> items = [
    "african",
    "asian",
    "caucasian",
    "hispanic",
    "middle_eastern",
    "mixed",
    "native_american",
    "pacific_islander",
    "prefer_not_say",
    "other"
  ];
}

class RelationshipModalSheet extends StatelessWidget {
  const RelationshipModalSheet({super.key, required this.status});
  final Function(String value) status;
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Container(
      width: size.width,
      decoration: BoxDecoration(
        color: context.theme.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: EdgeInsets.all(size.width * 0.06),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const AppText(
              text: "Relationship Status",
              fontSize: 20,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            const SizedBox(height: 24),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: items.length,
                separatorBuilder: (context, index) =>
                    Divider(color: Colors.white.withOpacity(0.05)),
                itemBuilder: (context, index) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: AppText(
                    text: items[index].capitalizeFirstChar(),
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                  trailing: const Icon(Icons.chevron_right,
                      color: Colors.white24, size: 20),
                  onTap: () {
                    status(items[index]);
                    Navigator.pop(context);
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  static List<String> items = [
    "single",
    "in_relationship",
    "engaged",
    "married",
    "divorced",
    "widowed",
    "complicated",
    "prefer_not_say"
  ];
}
