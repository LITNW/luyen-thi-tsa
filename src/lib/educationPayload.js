export function splitRecordIdentity(record) {
  const { id = '', ...values } = record;
  return { id, values };
}
