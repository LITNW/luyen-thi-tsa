(function attachEducationClassification(root) {
  function filterCourses(courses, levelId, levelCode, categoryId) {
    return (courses || []).filter((course) => course.is_active
      && course.education_level_id === levelId
      && (levelCode === 'university'
        ? course.category_id === categoryId
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

  function resetForCategoryChange(selection, categoryId) {
    return {
      ...selection,
      education_category_id: categoryId || '',
      education_subject_id: null,
    };
  }

  function isValidCourseSelection(course, levelId, levelCode, categoryId, currentCourseId) {
    if (!course || course.education_level_id !== levelId) return false;
    if (levelCode === 'university' && course.category_id !== categoryId) return false;
    if (levelCode !== 'university' && course.category_id != null) return false;
    return course.is_active || course.id === currentCourseId;
  }

  root.LITEducationClassification = Object.freeze({
    filterCourses,
    resetForLevelChange,
    resetForCategoryChange,
    isValidCourseSelection,
  });
})(globalThis);
