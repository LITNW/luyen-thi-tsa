(function attachEducationClassification(root) {
  function filterCourses(courses, levelId, levelCode, groupId) {
    return (courses || []).filter((course) => course.is_active
      && course.education_level_id === levelId
      && (levelCode === 'university'
        ? course.group_id === groupId
        : course.group_id == null));
  }

  function resetForLevelChange(selection, levelId) {
    return {
      ...selection,
      education_level_id: levelId || '',
      education_group_id: '',
      education_subject_id: null,
    };
  }

  function resetForGroupChange(selection, groupId) {
    return {
      ...selection,
      education_group_id: groupId || '',
      education_subject_id: null,
    };
  }

  function isValidCourseSelection(course, levelId, levelCode, groupId, currentCourseId) {
    if (!course || course.education_level_id !== levelId) return false;
    if (levelCode === 'university' && course.group_id !== groupId) return false;
    if (levelCode !== 'university' && course.group_id != null) return false;
    return course.is_active || course.id === currentCourseId;
  }

  root.LITEducationClassification = Object.freeze({
    filterCourses,
    resetForLevelChange,
    resetForGroupChange,
    isValidCourseSelection,
  });
})(globalThis);
