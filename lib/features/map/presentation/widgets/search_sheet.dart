import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/place_model.dart';

class SearchSheet extends StatefulWidget {
  final List<Place> results;
  final bool isSearching;
  final ValueChanged<String> onSearch;
  final ValueChanged<Place> onSelect;
  final VoidCallback onClose;
  final String hintText;

  const SearchSheet({
    super.key,
    required this.results,
    required this.isSearching,
    required this.onSearch,
    required this.onSelect,
    required this.onClose,
    this.hintText = 'Search destination',
  });

  @override
  State<SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<SearchSheet>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  late final AnimationController _animController;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _animController.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  void _closeWithAnimation() {
    _focusNode.unfocus();
    _animController.reverse().then((_) => widget.onClose());
  }

  @override
  void dispose() {
    _animController.dispose();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Container(
          color: AppTheme.bgDark,
          child: Column(
            children: [
          SizedBox(height: topPadding),
          // Search header
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingMd,
              vertical: AppTheme.spacingSm,
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _closeWithAnimation,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.bgElevated,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_back, size: 22, color: AppTheme.textPrimary),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.bgElevated,
                      borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                    ),
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      onChanged: widget.onSearch,
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppTheme.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: widget.hintText,
                        hintStyle: TextStyle(color: AppTheme.textMuted),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ),
                if (_controller.text.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _controller.clear();
                      widget.onSearch('');
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.close, size: 20, color: AppTheme.textMuted),
                    ),
                  ),
              ],
            ),
          ),

          if (widget.isSearching)
            LinearProgressIndicator(
              color: AppTheme.accent,
              backgroundColor: AppTheme.bgElevated,
            ),

          Divider(height: 1, color: AppTheme.bgSurface),

          // Results
          Expanded(
            child: widget.results.isEmpty
                ? _EmptyState(hasQuery: _controller.text.length >= 2)
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: widget.results.length,
                    itemBuilder: (context, index) {
                      final place = widget.results[index];
                      return _PlaceTile(
                        place: place,
                        onTap: () => widget.onSelect(place),
                      );
                    },
                  ),
          ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceTile extends StatelessWidget {
  final Place place;
  final VoidCallback onTap;

  const _PlaceTile({required this.place, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingMd + 8,
          vertical: 14,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.bgElevated,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: const Icon(
                Icons.location_on,
                color: AppTheme.accent,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (place.address.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      place.address,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: AppTheme.textMuted, size: 14),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasQuery;
  const _EmptyState({required this.hasQuery});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasQuery ? Icons.search_off : Icons.search,
            size: 48,
            color: AppTheme.textMuted,
          ),
          const SizedBox(height: 12),
          Text(
            hasQuery ? 'No results found' : 'Search for a place',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}
