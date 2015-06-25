module ProjectJobs
  extend ActiveSupport::Concern

  included do
    def schedule_delayed_analysis(delay = 0)
      return nil if repositories.empty?
      job = nil
      Job.transaction do
        job = create_or_update_analyze_jobs(delay)
      end
      job
    end

    def ensure_job(priority = 0)
      update_activity_level
      Job.transaction do
        return if deleted? || repositories.empty? || incomplete_job
        repositories.each { |r| return if r.ensure_job }
        create_new_job? ? AnalyzeJob.create(project: self, priority: priority) : update_logged_at
      end
    end

    def forge_match
      forge && Forge::Match.new(forge, owner_at_forge, name_at_forge)
    end

    def forge_match=(m)
      self.forge_id       = m && m.forge_id
      self.owner_at_forge = m && m.owner_at_forge
      self.name_at_forge  = m && m.name_at_forge
    end

    def guess_forge
      if repositories.any?
        matches = repositories.map(&:forge_match).compact.sort.uniq
        return matches.first if matches.size == 1
      end
      Forge::Match.first(url)
    end
  end

  private

  def create_or_update_analyze_jobs(delay)
    job = incomplete_job
    if job.nil?
      job = AnalyzeJob.create(project: self, wait_until: Time.now.utc + delay)
    elsif job.is_a? AnalyzeJob
      job.update_attribute(:wait_until, Time.now.utc + delay)
    end
    job
  end

  def create_new_job?
    best_analysis.blank? || best_analysis.created_at < 1.month.ago ||
      sloc_sets_out_of_date? || !best_analysis.thirty_day_summary
  end

  def update_logged_at
    sloc_set_ids = AnalysisSlocSet.where(analysis_id: best_analysis_id).pluck(:sloc_set_id)
    best_analysis.update_attributes(logged_at: SlocSet.where(id: sloc_set_ids).minimum(:logged_at))
  end

  def update_activity_level
    return if best_analysis.blank? || best_analysis.updated_on >= 1.month.ago
    activity_index = Project::ActivityLevelIndex::ACTIVITY_LEVEL_INDEX[project.best_analysis.activity_level]
    update_attribute(:activity_level_index, activity_index) if activity_index != activity_level_index
  end

  def incomplete_job
    jobs.where.not(status: Job::STATUS_COMPLETED).first ||
      jobs.where(repository_id: repositories.map(&:id)).where.not(status: Job::STATUS_COMPLETED).first
  end

  def sloc_sets_out_of_date?
    return false if best_analysis.blank?
    best_sloc_set_ids = repositories.map(&:best_code_set).compact.map(&:best_sloc_set_id)
    return true if (best_analysis.sloc_sets.map(&:id) - best_sloc_set_ids).present?
    update_analyis_sloc_sets
  end

  def update_analyis_sloc_sets
    sloc_sets_out_of_date = false
    best_analysis.analysis_sloc_sets.each do |ass|
      sloc_sets_out_of_date = true && break if ass.as_of != ass.sloc_set.as_of
      ass.update_attributes(logged_at: ass.sloc_set.logged_at)
    end
    sloc_sets_out_of_date
  end
end
