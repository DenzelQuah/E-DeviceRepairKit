import 'package:e_repairkit/view/chatview.dart';
import 'package:e_repairkit/viewmodels/chat_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ModeSelectionView extends StatefulWidget {
  const ModeSelectionView({super.key});

  @override
  State<ModeSelectionView> createState() => _ModeSelectionViewState();
}

class _ModeSelectionViewState extends State<ModeSelectionView> {
  // Store the local state for this page
  String _selectedMode = 'practical';
  double _selectedTemp = 0.2;

  @override
  void initState() {
    // Start with the ViewModel's current settings
    final vm = context.read<ChatViewModel>();
    _selectedMode = vm.mode;
    _selectedTemp = vm.temperature;
    super.initState();
  }

  void _startChat() {
    final vm = context.read<ChatViewModel>();
    // Save the settings to the ViewModel
    vm.setMode(_selectedMode);
    vm.setTemperature(_selectedTemp);
    
    // Replace this page with the ChatView
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (cxt) => const ChatView()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Your Mode'),
        backgroundColor: theme.colorScheme.surface,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'How should your AI assistant behave?',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Choose a style for your repair session.',
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // --- Side-by-side Mode Cards ---
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: _ModeSelectionCard(
                        icon: Icons.check_circle_outline,
                        title: 'Practical',
                        subtitle: 'Safe, reliable fixes.',
                        isSelected: _selectedMode == 'practical',
                        onTap: () {
                          setState(() {
                            _selectedMode = 'practical';
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _ModeSelectionCard(
                        icon: Icons.science_outlined,
                        title: 'Experimental',
                        subtitle: 'Creative, clever hacks.',
                        isSelected: _selectedMode == 'experimental',
                        onTap: () {
                          setState(() {
                            _selectedMode = 'experimental';
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),

            // --- "Aesthetic" Creativity Slider ---
            _CreativitySlider(
              value: _selectedTemp,
              onChanged: (newValue) {
                setState(() {
                  _selectedTemp = newValue;
                });
              },
            ),
            
            const SizedBox(height: 40),

            // --- Start Chat Button ---
             ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  backgroundColor: theme.primaryColor,
                  foregroundColor: theme.colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _startChat,
                child: const Text('Start Chat'),
              ),
          ],
        ),
      ),
    );
  }
}

// --- NEW WIDGET: Mode Selection Card ---
class _ModeSelectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeSelectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        height: 160, // Give the card a fixed height
        decoration: BoxDecoration(
          color: isSelected
              ? theme.primaryColor.withOpacity(0.1)
              : theme.colorScheme.surface,
          border: Border.all(
            color: isSelected ? theme.primaryColor : theme.colorScheme.outline.withOpacity(0.3),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected ? [
             BoxShadow(
              color: theme.primaryColor.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ] : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 32,
                color: isSelected
                    ? theme.primaryColor
                    : theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              title,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// --- NEW WIDGET: "Aesthetic" Creativity Slider ---
class _CreativitySlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const _CreativitySlider({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String label = _getCreativityLabel(value);
    
    return Column(
      children: [
        Text(
          'AI Creativity Level',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
          Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.primaryColor, fontWeight: FontWeight.bold),
        ),
        Slider(
          value: value,
          min: 0.0,
          max: 1.0,
          divisions: 10,
          label: value.toStringAsFixed(2),
          activeColor: theme.primaryColor,
          inactiveColor: Colors.blue,
          onChanged: onChanged,
        ),
      ],
    );
  }

  String _getCreativityLabel(double value) {
    if (value < 0.2) return 'Precise & Focused';
    if (value < 0.5) return 'Balanced';
    if (value < 0.8) return 'Creative';
    return 'Highly Imaginative';
  }
}
