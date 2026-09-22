-- Built-in categories (user_id null = shared/global, readable by everyone).
-- These mirror the Categories defined in lib/models/category.dart.
insert into public.categories (id, user_id, name, icon, color, is_builtin) values
  ('food',          null, 'Food & Dining',     'restaurant',           '#FF8A34', true),
  ('shopping',      null, 'Shopping',           'shopping_bag',         '#7C5CFC', true),
  ('travel',        null, 'Travel',             'directions_car',       '#2FB1F0', true),
  ('bills',         null, 'Bills & Utilities',  'receipt_long',         '#F5432C', true),
  ('entertainment', null, 'Entertainment',      'movie',                '#EC4899', true),
  ('groceries',     null, 'Groceries',          'local_grocery_store',  '#27C093', true),
  ('health',        null, 'Health',             'favorite',             '#EF4444', true),
  ('income',        null, 'Income',             'account_balance_wallet','#27C093', true),
  ('transfer',      null, 'Transfer',           'swap_horiz',           '#64748B', true),
  ('other',         null, 'Other',              'category',             '#8A8D96', true)
on conflict (id) do nothing;
