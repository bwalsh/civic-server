class EvidenceItemModerationsController < ModerationsController
  private
  def moderated_object
    EvidenceItem.view_scope.find_by_id!(params[:evidence_item_id])
  end

  def moderation_params
    if params[:pubmed_id].present?
      params[:source] = params[:pubmed_id]
    end
    params.permit(:clinical_significance, :evidence_direction, :text, :description, :rating,
     :evidence_level, :variant_origin, :evidence_direction, :source, :evidence_type)
  end

  def additional_moderation_params
    params.permit(drugs: [])
  end

  def presenter_class
   EvidenceItemPresenter
  end
end