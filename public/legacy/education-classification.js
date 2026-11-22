(function attachEducationClassification(root) {
  function filterCourses(courses, levelId, levelCode, groupId) {
    return (courses || []).filter((course) => course.is_active
      && course.education_level_id === levelId
      && (levelCode === 'university'
        ? course.category_id === groupId
        : course.category_id == null));
  }

  function resetForLevelChange(selection, levelId) {
    return {
      ...selection,
      education_level_id: levelId || '',
      education_category_id: '',
      education_subject_id: null,
    };
  }

  function resetForGroupChange(selection, groupId) {
    return {
      ...selection,
      education_category_id: groupId || '',
      education_subject_id: null,
    };
  }

  function isValidCourseSelection(course, levelId, levelCode, groupId, currentCourseId) {
    if (!course || course.education_level_id !== levelId) return false;
    if (levelCode === 'university' && course.category_id !== groupId) return false;
    if (levelCode !== 'university' && course.category_id != null) return false;
    return course.is_active || course.id === currentCourseId;
  }

  root.LITEducationClassification = Object.freeze({
    filterCourses,
    resetForLevelChange,
    resetForGroupChange,
    isValidCourseSelection,
  });
})(globalThis);
