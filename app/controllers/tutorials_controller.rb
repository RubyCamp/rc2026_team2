class TutorialsController < ApplicationController
  def index
    @profiles = TutorialProfile.published.sort_by(&:name)
    if params[:category].present?
      @profiles = @profiles.select { |profile| profile.category == params[:category] }
    end
  end

  def debug
    @profile = TutorialProfile.find(1)
  end

  def show
    @profile = TutorialProfile.find(params[:id])
  end
end
