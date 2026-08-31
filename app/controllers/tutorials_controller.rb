class TutorialsController < ApplicationController
  def index
    @profiles = TutorialProfile.published.sort_by(&:name)
  end

  def debug
    @profile = TutorialProfile.find(1)
  end
end
