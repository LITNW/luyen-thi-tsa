export function splitRecordIdentity(record) {
  const { id = '', ...values } = record;
  return { id, values };
}

export function buildEducationCoursePayload(values, educationLevelId, university) {
  return {
    ...values,
    education_level_id: educationLevelId,
    category_id: university ? values.category_id || null : null,
    local_code: values.local_code.trim() || null,
    display_order: Number(values.display_order) || 0,
  };
}
