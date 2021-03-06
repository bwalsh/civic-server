class EvidenceItemTsvPresenter
  def self.objects
    EvidenceItem.eager_load(:disease, :source, :evidence_type, :evidence_level, :drugs, variant: [:gene])
      .where(status: 'accepted')
  end

  def self.headers
    [
      'gene',
      'entrez_id',
      'variant',
      'disease',
      'doid',
      'drugs',
      'pubchem_ids',
      'evidence_type',
      'evidence_direction',
      'clinical_significance',
      'statement',
      'pubmed_id',
      'citation',
      'rating'
    ]
  end

  def self.row_from_object(ei)
    [
      ei.variant.gene.name,
      ei.variant.gene.entrez_id,
      ei.variant.name,
      ei.disease.name,
      ei.disease.doid,
      ei.drugs.map(&:name).join(','),
      ei.drugs.map(&:pubchem_id).join(','),
      ei.evidence_type.evidence_type,
      ei.evidence_direction,
      ei.clinical_significance,
      ei.description,
      ei.source.pubmed_id,
      ei.source.description,
      ei.rating
    ]
  end

  def self.file_name
    'ClinicalEvidenceSummaries.tsv'
  end
end
