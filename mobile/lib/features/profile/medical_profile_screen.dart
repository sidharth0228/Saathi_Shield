import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../models/medical_profile_model.dart';
import '../../providers/medical_provider.dart';

class MedicalProfileScreen extends ConsumerStatefulWidget {
  const MedicalProfileScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<MedicalProfileScreen> createState() => _MedicalProfileScreenState();
}

class _MedicalProfileScreenState extends ConsumerState<MedicalProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _allergiesController = TextEditingController();
  final _medicationsController = TextEditingController();
  final _conditionsController = TextEditingController();
  String _selectedBloodGroup = 'Unknown';
  bool _organDonor = false;
  bool _initialized = false;

  final List<String> _bloodGroups = [
    'Unknown',
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];

  @override
  void dispose() {
    _allergiesController.dispose();
    _medicationsController.dispose();
    _conditionsController.dispose();
    super.dispose();
  }

  void _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final profile = MedicalProfileModel(
      bloodGroup: _selectedBloodGroup == 'Unknown' ? '' : _selectedBloodGroup,
      allergies: _allergiesController.text.trim(),
      medications: _medicationsController.text.trim(),
      medicalConditions: _conditionsController.text.trim(),
      organDonor: _organDonor,
    );

    final success = await ref.read(medicalProvider.notifier).updateProfile(profile);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Medical profile updated successfully.'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      } else {
        final error = ref.read(medicalProvider).errorMessage ?? 'An error occurred';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final medicalState = ref.watch(medicalProvider);

    // Initial setup when profile is retrieved
    if (medicalState.profile != null && !_initialized) {
      final p = medicalState.profile!;
      _allergiesController.text = p.allergies;
      _medicationsController.text = p.medications;
      _conditionsController.text = p.medicalConditions;
      _selectedBloodGroup = p.bloodGroup.isEmpty ? 'Unknown' : p.bloodGroup;
      _organDonor = p.organDonor;
      _initialized = true;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Medical Profile'),
      ),
      body: medicalState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 8),
                        Text(
                          'Emergency Medical Details',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'This information will be displayed to emergency responders and trusted contacts during an active SOS alert.',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                        const SizedBox(height: 20),

                        // Blood Group Card
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Primary Vitals',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<String>(
                                  value: _selectedBloodGroup,
                                  decoration: const InputDecoration(
                                    labelText: 'Blood Group',
                                    prefixIcon: Icon(Icons.bloodtype, color: AppTheme.accentSosRed),
                                  ),
                                  items: _bloodGroups.map((group) {
                                    return DropdownMenuItem(
                                      value: group,
                                      child: Text(group),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() {
                                        _selectedBloodGroup = val;
                                      });
                                    }
                                  },
                                ),
                                const SizedBox(height: 16),
                                SwitchListTile(
                                  title: const Text('Organ Donor Status'),
                                  subtitle: const Text('Are you registered as an organ donor?'),
                                  secondary: const Icon(
                                    Icons.favorite,
                                    color: AppTheme.accentSosRed,
                                  ),
                                  value: _organDonor,
                                  onChanged: (bool value) {
                                    setState(() {
                                      _organDonor = value;
                                    });
                                  },
                                  activeColor: AppTheme.primaryBlue,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Medical Conditions Card
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Detailed Medical Info',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _conditionsController,
                                  decoration: const InputDecoration(
                                    labelText: 'Medical Conditions',
                                    hintText: 'e.g. Asthma, Diabetes, Hypertension',
                                    prefixIcon: Icon(Icons.healing_outlined),
                                  ),
                                  maxLines: 2,
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _allergiesController,
                                  decoration: const InputDecoration(
                                    labelText: 'Allergies',
                                    hintText: 'e.g. Peanuts, Penicillin, Latex',
                                    prefixIcon: Icon(Icons.warning_amber_rounded),
                                  ),
                                  maxLines: 2,
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _medicationsController,
                                  decoration: const InputDecoration(
                                    labelText: 'Current Medications',
                                    hintText: 'e.g. Albuterol inhaler, Metformin',
                                    prefixIcon: Icon(Icons.medication_outlined),
                                  ),
                                  maxLines: 2,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        ElevatedButton(
                          onPressed: medicalState.isSaving ? null : _saveProfile,
                          child: medicalState.isSaving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text('Save Profile'),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
                if (medicalState.isSaving)
                  Container(
                    color: Colors.black.withOpacity(0.15),
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
              ],
            ),
    );
  }
}
