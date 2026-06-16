const I18N_PREFIX =
  'LEAD_RETARGETING.FORM.CUSTOM_ATTRIBUTE_FILTERS.OPERATORS';

export const OPERATOR_I18N_KEYS = {
  equals: `${I18N_PREFIX}.equals`,
  not_equals: `${I18N_PREFIX}.not_equals`,
  contains: `${I18N_PREFIX}.contains`,
  not_contains: `${I18N_PREFIX}.not_contains`,
  starts_with: `${I18N_PREFIX}.starts_with`,
  ends_with: `${I18N_PREFIX}.ends_with`,
  greater_than: `${I18N_PREFIX}.greater_than`,
  less_than: `${I18N_PREFIX}.less_than`,
  gte: `${I18N_PREFIX}.gte`,
  lte: `${I18N_PREFIX}.lte`,
  before: `${I18N_PREFIX}.before`,
  after: `${I18N_PREFIX}.after`,
  between: `${I18N_PREFIX}.between`,
  includes_any: `${I18N_PREFIX}.includes_any`,
  present: `${I18N_PREFIX}.present`,
  blank: `${I18N_PREFIX}.blank`,
};

const TEXT_OPS = [
  'equals',
  'not_equals',
  'contains',
  'not_contains',
  'starts_with',
  'ends_with',
  'present',
  'blank',
];
const NUMBER_OPS = [
  'equals',
  'not_equals',
  'greater_than',
  'less_than',
  'gte',
  'lte',
  'between',
  'present',
  'blank',
];
const DATE_OPS = ['before', 'after', 'between', 'present', 'blank'];
const LIST_OPS = ['equals', 'not_equals', 'includes_any', 'present', 'blank'];
const BOOL_OPS = ['equals', 'present', 'blank'];

export const OPERATORS_BY_TYPE = {
  text: TEXT_OPS,
  link: TEXT_OPS,
  number: NUMBER_OPS,
  currency: NUMBER_OPS,
  percent: NUMBER_OPS,
  date: DATE_OPS,
  datetime: DATE_OPS,
  checkbox: BOOL_OPS,
  list: LIST_OPS,
};

export const needsTwoValues = operator => operator === 'between';
export const needsNoValue = operator => ['present', 'blank'].includes(operator);
