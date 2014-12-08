class LogosController < SettingsController
  # before_action :login_required, except: :new
  # before_action :check_project
  # layout_params :auto_layout_params
  before_action :set_project_or_organization, only: [:destroy, :create, :new]
  before_action :set_logo, only: :destroy
  around_action :edit_authorized?, only: :create

  def new
    @logo = Logo.new
  end

  def create
    create_logo
    update_parent_logo
    flash[:success] = t('.success')
    redirect_to action: :new
  end

  def destroy
    @project_or_organization.update_attribute(:logo_id, nil)
    @logo.destroy ? flash[:success] = t('.success') : flash[:error] = t('.error')
    redirect_to action: :new
  end

  private

  def edit_authorized?
    if @project_or_organization.edit_authorized?
      yield
    else
      redirect_to new_session_path, flash: { error: t('.permisson_denied') }
    end
  end

  def create_logo
    return if params[:logo_id].present?

    @logo = Logo.new(logo_params)
    return if @logo.save

    flash[:error] = t('.error')
    redirect_to action: :new && return
  end

  def update_parent_logo
    @project_or_organization.update_attribute(:logo_id, params[:logo_id] || @logo.id)
  end

  def set_project_or_organization
    @project_or_organization = if params[:project_id]
                                 Project.find(params[:project_id])
                               elsif params[:organization_id]
                                 Organization.find(params[:organization_id])
                               end
  end

  def set_logo
    @logo = @project_or_organization.logo
  end

  def logo_params
    params.require(:logo).permit(:logo, :url, :attachment)
  end
end
