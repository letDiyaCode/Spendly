import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../core/models/settlement.dart';
import '../../core/models/enums.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/shared_widgets.dart';
import '../auth/auth_provider.dart';
import 'settlement_provider.dart';


class SettlementsScreen extends ConsumerStatefulWidget {
  const SettlementsScreen({super.key});

  @override
  ConsumerState<SettlementsScreen> createState() => _SettlementsScreenState();
}

class _SettlementsScreenState extends ConsumerState<SettlementsScreen> {
  final _txnController = TextEditingController();
  final _amountController = TextEditingController();
  String? _selectedFriendId;
  String? _proofImagePath;
  final _picker = ImagePicker();

  @override
  void dispose() {
    _txnController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 55,
        maxWidth: 1000,
        maxHeight: 1000,
      );
      if (picked != null) setState(() => _proofImagePath = picked.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open picker: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final balanceMap = ref.watch(globalBalancesProvider);
    final settlements = ref.watch(settlementProvider); // Use settlementProvider directly
    final usersAsync = ref.watch(allUsersProvider);
    final users = usersAsync.value ?? [];
    final user = ref.watch(authProvider);

    final net = ref.watch(overallBalanceProvider)['net'] ?? 0.0;
    final owe = ref.watch(overallBalanceProvider)['owe'] ?? 0.0;
    final owed = ref.watch(overallBalanceProvider)['owed'] ?? 0.0;

    final friends = users.where((u) => u.id != user?.id).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Settlements')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Net Balance Summary
            SpendlyCard(
              gradient: net >= 0
                  ? SpendlyColors.greenGradient
                  : SpendlyColors.primaryGradient,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Net Balance',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 8),
                  Text(
                    AppFormatters.currency(net.abs()),
                    style: TextStyle(
                      color: net >= 0
                          ? const Color(0xFF34D399)
                          : const Color(0xFFF87171),
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    net >= 0
                        ? 'You are owed this amount'
                        : 'You owe this amount',
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ],
              ),
            ).animate().fadeIn(),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMiniStatCard('You Owe', owe, SpendlyColors.danger, Icons.arrow_upward_rounded),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMiniStatCard('Owed to You', owed, SpendlyColors.success, Icons.arrow_downward_rounded),
                ),
              ],
            ).animate().fadeIn(delay: 100.ms),
            const SizedBox(height: 24),

            // Quick Settle
            const SectionHeader(title: 'Record a Settlement'),
            const SizedBox(height: 12),
            SpendlyCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: SpendlyColors.neutral200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.person_outline, color: SpendlyColors.neutral500, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButton<String>(
                            value: _selectedFriendId,
                            hint: const Text('Select Friend'),
                            isExpanded: true,
                            underline: const SizedBox.shrink(),
                            items: friends
                                .map((u) => DropdownMenuItem(
                                    value: u.id,
                                    child: Text(u.name)))
                                .toList(),
                            onChanged: (v) {
                              setState(() {
                                _selectedFriendId = v;
                                if (v != null) {
                                  final b = balanceMap[v] ?? 0;
                                  _amountController.text = b.abs().toStringAsFixed(2);
                                }
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      prefixText: '₹ ',
                      prefixIcon: Icon(Icons.currency_rupee_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _txnController,
                    decoration: const InputDecoration(
                      labelText: 'Transaction ID (optional)',
                      prefixIcon: Icon(Icons.tag_rounded),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickImage(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt_outlined, size: 16),
                        label: const Text('Camera'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickImage(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined, size: 16),
                        label: const Text('Gallery'),
                      ),
                    ),
                  ]),
                  if (_proofImagePath != null) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(File(_proofImagePath!), height: 80, width: double.infinity, fit: BoxFit.cover),
                    ),
                  ],
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: _selectedFriendId == null ? null : _initiateSettlement,
                    child: Container(
                      width: double.infinity,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: _selectedFriendId == null ? null : SpendlyColors.primaryGradient,
                        color: _selectedFriendId == null ? SpendlyColors.neutral200 : null,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text('Submit Settlement', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // History
            SectionHeader(title: 'Settlement Activity', actionLabel: '${settlements.length}'),
            const SizedBox(height: 12),
            if (settlements.isEmpty)
              const EmptyState(icon: Icons.history, title: 'No activity', subtitle: 'Settlements will appear here')
            else
              ...settlements.map((s) => _buildSettlementCard(context, ref, s, user?.id ?? '')),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStatCard(String label, double amount, Color color, IconData icon) {
    return SpendlyCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(icon, color: color, size: 12), const SizedBox(width: 4), Text(label, style: const TextStyle(fontSize: 10, color: SpendlyColors.neutral500))]),
          const SizedBox(height: 4),
          Text(AppFormatters.currency(amount), style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildSettlementCard(BuildContext context, WidgetRef ref, Settlement s, String currentUserId) {
    final isReceiving = s.toUserId == currentUserId;
    final otherUserId = isReceiving ? s.fromUserId : s.toUserId;
    final otherUser = ref.read(userByIdProvider(otherUserId));

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SpendlyCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                UserAvatar(name: otherUser?.name ?? '?', userId: otherUserId, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(isReceiving ? '${otherUser?.name.split(' ').first} paid you' : 'You paid ${otherUser?.name.split(' ').first}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(AppFormatters.shortDate(s.createdAt), style: const TextStyle(fontSize: 11, color: SpendlyColors.neutral400)),
                    ],
                  ),
                ),
                Text(AppFormatters.currency(s.amount), style: TextStyle(fontWeight: FontWeight.w900, color: isReceiving ? SpendlyColors.success : SpendlyColors.danger)),
              ],
            ),
            const SizedBox(height: 12),
            if (s.proofUrl != null) ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => _showProofDialog(context, s.proofUrl!),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SpendlyImage(
                      source: s.proofUrl!,
                      height: 100,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.black26,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.zoom_in_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                _buildStatusChip(s),
                const Spacer(),
                if (s.isPending && isReceiving) ...[
                  _ActionButton(
                    label: 'Approve',
                    color: SpendlyColors.success,
                    onPressed: () => ref.read(settlementActionProvider).approveSettlement(s.id, currentUserId),
                  ),
                  const SizedBox(width: 8),
                  _ActionButton(
                    label: 'Reject',
                    color: SpendlyColors.danger,
                    onPressed: () => ref.read(settlementActionProvider).rejectSettlement(s.id, currentUserId),
                  ),
                ]
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(Settlement s) {
    if (s.isVerified) return StatusBadge.verified();
    if (s.isRejected) return StatusBadge.rejected();
    return StatusBadge.pending();
  }

  Future<void> _initiateSettlement() async {
    final user = ref.read(authProvider);
    if (user == null || _selectedFriendId == null) return;

    final amount = double.tryParse(_amountController.text) ?? 0;
    if (amount <= 0) return;

    final balances = ref.read(globalBalancesProvider);
    final balance = balances[_selectedFriendId!] ?? 0;

    if (balance.abs() < 0.01) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pending balance to settle.')),
      );
      return;
    }

    final s = Settlement(
      id: const Uuid().v4(),
      fromUserId: balance <= 0 ? user.id : _selectedFriendId!,
      toUserId: balance <= 0 ? _selectedFriendId! : user.id,
      amount: amount,
      status: SettlementStatus.pendingVerification,
      createdAt: DateTime.now(),
      transactionId: _txnController.text.trim().isEmpty
          ? null
          : _txnController.text.trim(),
      proofImagePath: _proofImagePath,
    );

    try {
      await ref.read(settlementActionProvider).createSettlement(
            s,
            imageFile: _proofImagePath != null ? File(_proofImagePath!) : null,
          );
      if (!mounted) return;

      final isIncomingRecordedByMe = s.toUserId == user.id;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isIncomingRecordedByMe
              ? 'Settlement recorded and auto-verified ✓'
              : 'Settlement request submitted ✓'),
        ),
      );
      setState(() {
        _selectedFriendId = null;
        _proofImagePath = null;
      });
      _amountController.clear();
      _txnController.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  void _showProofDialog(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 32),
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: InteractiveViewer(
                child: SpendlyImage(
                  source: url,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatefulWidget {
  final String label;
  final Color color;
  final Future<void> Function() onPressed;

  const _ActionButton({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return _loading
        ? SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(widget.color),
            ),
          )
        : TextButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              setState(() => _loading = true);
              try {
                await widget.onPressed();
              } catch (e) {
                if (!mounted) return;
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(e.toString().replaceFirst('Exception: ', '')),
                  ),
                );
              } finally {
                if (mounted) setState(() => _loading = false);
              }
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              widget.label,
              style: TextStyle(
                color: widget.color,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          );
  }
}
