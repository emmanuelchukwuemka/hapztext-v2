import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:haptext_api/bloc/auth/cubit/auth_cubit.dart';
import 'package:haptext_api/bloc/home/cubit/home_cubit.dart';
import 'package:haptext_api/exports.dart';
import 'package:haptext_api/utils/extensions.dart';
import 'package:provider/provider.dart';
import 'package:haptext_api/services/chat_ui/auth_provider.dart';

class Register extends StatefulWidget {
  const Register({super.key});

  @override
  State<Register> createState() => _RegisterState();
}

class _RegisterState extends State<Register> {
  final _formKey = GlobalKey<FormState>();

  bool hidePassword1 = true;
  bool hidePassword2 = true;
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _selectDate(BuildContext context, AuthCubit watchAuth) async {
    final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: DateTime.now()
            .subtract(const Duration(days: 365 * 18)), // Default 18 years ago
        firstDate: DateTime(1900, 1),
        lastDate: DateTime.now());
    if (picked != null) {
      setState(() {
        watchAuth.birthDateController.text =
            "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final watchAuth = context.watch<AuthCubit>();
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthLoginState) {
          // Sync token to chat AuthProvider
          final authProvider = context.read<AuthProvider>();
          final token = watchAuth.useInfo.tokens?.auth ?? '';
          final userId = watchAuth.useInfo.id?.toString();
          authProvider.setTokenFromSession(token, userId);

          context.go(RouteName.bottomNav.path);
          context.read<HomeCubit>().fetchPosts();
        }
      },
      child: AbsorbPointer(
        absorbing: watchAuth.state is AuthLoadingState,
        child: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 30.0),
                const Image(
                  image: AssetImage("assets/images/hapz_logo.png"),
                  width: 125,
                ),
                const SizedBox(height: 30.0),
                const Text(
                  'Create an Account',
                  style: TextStyle(
                    // color: context.theme.titleTextColor,
                    fontSize: 26.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                  margin:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: _pickImage,
                          child: CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.grey[800],
                            backgroundImage: _profileImage != null
                                ? FileImage(_profileImage!)
                                : null,
                            child: _profileImage == null
                                ? const Icon(Icons.add_a_photo,
                                    size: 40, color: Colors.orange)
                                : null,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          "Profile Picture",
                          style: TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 20),
                        InputField(
                          controller: watchAuth.firstNameController,
                          keyboardType: TextInputType.text,
                          hintText: 'First Name',
                          prefix:
                              const Icon(Icons.person, color: Colors.orange),
                        ),
                        const SizedBox(height: 20),
                        InputField(
                          controller: watchAuth.lastNameController,
                          keyboardType: TextInputType.text,
                          hintText: 'Last Name',
                          prefix:
                              const Icon(Icons.person, color: Colors.orange),
                        ),
                        const SizedBox(height: 20),
                        InputField(
                          controller: watchAuth.usernameController,
                          keyboardType: TextInputType.text,
                          hintText: 'Username',
                          prefix:
                              const Icon(Icons.person, color: Colors.orange),
                        ),
                        const SizedBox(height: 20),
                        DropdownButtonFormField<String>(
                          value: watchAuth.selectedGender,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                            filled: true,
                            fillColor: const Color(0xFF1E1E1E),
                            hintText: 'Gender',
                            prefixIcon:
                                const Icon(Icons.wc, color: Colors.orange),
                          ),
                          dropdownColor: const Color(0xFF1E1E1E),
                          items: const [
                            DropdownMenuItem(
                                value: 'male', child: Text('Male')),
                            DropdownMenuItem(
                                value: 'female', child: Text('Female')),
                            DropdownMenuItem(
                                value: 'other', child: Text('Other')),
                            DropdownMenuItem(
                                value: 'prefer_not_say',
                                child: Text('Prefer not to say')),
                          ],
                          onChanged: (value) {
                            setState(() {
                              watchAuth.selectedGender = value;
                            });
                          },
                        ),
                        const SizedBox(height: 20),
                        GestureDetector(
                          onTap: () => _selectDate(context, watchAuth),
                          child: AbsorbPointer(
                            child: InputField(
                              controller: watchAuth.birthDateController,
                              keyboardType: TextInputType.datetime,
                              hintText: 'Birth Date',
                              prefix:
                                  const Icon(Icons.cake, color: Colors.orange),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        InputField(
                          controller: watchAuth.locationController,
                          keyboardType: TextInputType.text,
                          hintText: 'Location',
                          prefix: const Icon(Icons.location_on,
                              color: Colors.orange),
                        ),
                        const SizedBox(height: 20),
                        DropdownButtonFormField<String>(
                          value: watchAuth.selectedRelationshipStatus,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                            filled: true,
                            fillColor: const Color(0xFF1E1E1E),
                            hintText: 'Relationship Status',
                            prefixIcon: const Icon(Icons.favorite,
                                color: Colors.orange),
                          ),
                          dropdownColor: const Color(0xFF1E1E1E),
                          items: const [
                            DropdownMenuItem(
                                value: 'single', child: Text('Single')),
                            DropdownMenuItem(
                                value: 'in_relationship',
                                child: Text('In a Relationship')),
                            DropdownMenuItem(
                                value: 'engaged', child: Text('Engaged')),
                            DropdownMenuItem(
                                value: 'married', child: Text('Married')),
                            DropdownMenuItem(
                                value: 'complicated',
                                child: Text("It's Complicated")),
                            DropdownMenuItem(
                                value: 'prefer_not_say',
                                child: Text('Prefer not to say')),
                          ],
                          onChanged: (value) {
                            setState(() {
                              watchAuth.selectedRelationshipStatus = value;
                            });
                          },
                        ),
                        const SizedBox(height: 20),
                        InputField(
                          controller: watchAuth.occupationController,
                          keyboardType: TextInputType.text,
                          hintText: 'Occupation',
                          prefix: const Icon(Icons.work, color: Colors.orange),
                        ),
                        const SizedBox(height: 20),
                        InputField(
                            controller: watchAuth.emailController,
                            keyboardType: TextInputType.emailAddress,
                            validator: (input) => input?.validateEmail(),
                            hintText: 'Email Address',
                            prefix:
                                const Icon(Icons.email, color: Colors.orange)),
                        const SizedBox(height: 20),
                        InputField(
                          controller: watchAuth.passwordController,
                          keyboardType: TextInputType.text,
                          validator: (input) => input?.validatePassword(),
                          isPassword: hidePassword1,
                          hintText: 'Password',
                          prefix: const Icon(
                            Icons.lock,
                            color: Colors.orange,
                          ),
                        ),
                        const SizedBox(height: 20),
                        InputField(
                          controller: watchAuth.passwordConfirmController,
                          keyboardType: TextInputType.text,
                          // onSaved: ,

                          validator: (input) =>
                              input! != watchAuth.passwordController.text
                                  ? "Password Mismatch"
                                  : null,
                          isPassword: hidePassword2,

                          prefix: const Icon(Icons.lock, color: Colors.orange),
                        ),
                        const SizedBox(height: 30.0),
                        Appbutton(
                          label: "Sign up",
                          isLoading: watchAuth.state is AuthLoadingState,
                          onTap: () {
                            if (_formKey.currentState?.validate() ?? false) {
                              watchAuth.profileImage = _profileImage;
                              watchAuth.registerUser();
                            }
                          },
                        ),
                        const SizedBox(height: 30.0),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const AppText(
                                text: 'Already have an Account? ',
                                color: Colors.white),
                            GestureDetector(
                                onTap: () => context.push(RouteName.login.path),
                                child: const AppText(
                                    text: 'Sign In', color: Colors.white)),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
