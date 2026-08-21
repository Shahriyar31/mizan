import os
path = os.path.expanduser('~/develop/ummahapp/lib/features/discover/screens/prophet_detail_screen.dart')
with open(path) as f:
    text = f.read()

old = '''      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.gold),
          const SizedBox(width: 8),
          Text(
            text,
            style: AppTypography.labelSmall(color: AppColors.gold),
          ),
        ],
      ),'''

new = '''      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.gold),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: AppTypography.labelSmall(color: AppColors.gold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),'''

if old in text:
    text = text.replace(old, new)
    with open(path, 'w') as f:
        f.write(text)
    print('✓ Fixed citation badge overflow')
else:
    print('WARN: pattern not found')
