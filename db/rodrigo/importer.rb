class Importer

  attr_accessor :parsed_file, :evidence 

    # base cgd model, connect to cgd DB
  class Row < OpenStruct

    # given: "F317L/V/I/C"
    # return ["F317L", "F317V", "F317I", "F317C"]
    def variant_names(variant_name)
      a = variant_name.split("/") 
      root = a.shift
      a.unshift(root.last)
      root = root[0...-1]
      a = a.map {|x| root + x }    
    end

    # given a variant name of the form "GENE Aribtrary string with VARIANTNAME embedded"  
    # check potential variant names against extract from cosmic complete extract
    # sftp  walsbr@ohsu.edu@sftp-cancer.sanger.ac.uk:files/grch38/cosmic/v72/CosmicCompleteExport.tsv.gz 
    # vanderbuilt's http://www.mycancergenome.org/
    # CGD::TherapyVariant.all.each {|v| v.ensure_variant != v.comment}
    @@cosmic_variants = nil 
    def fetch_variant_description(variant_name)
      if @@cosmic_variants == nil        
        @@cosmic_variants = IO.readlines(File.join(__dir__, 'cosmic-variant-aa-names.txt')).each {|l| l.chomp!}
      end
      #variant_name.split('/').slice(0,0).select{|n| n == n.upcase }.each { |v|
      [variant_name].each { |v|
        # url = "http://searchvu.vanderbilt.edu/search?as_epq=#{v}+mutation&client=mycancergenome"
        # xml = Nokogiri::XML(Scrapers::Util.make_get_request(url)) 
        # return v if xml.xpath("/GSP/RES[1]").size == 1      
        # the variant description is found here ... 
        # fetch the url at /GSP/RES[1]/R/U  ... url = xml.xpath("/GSP/RES[1]/R[1]/U[1]").text
        # apply this xpath to resulting document xpath = '//*[@id="section-content-container"]/div[3]/div/p[1]'
        #  xml.xpath('//*[@id="section-content-container"]/div[3]/div/p[1]').text
        matches = @@cosmic_variants.select {|a| a.index(v) != nil  }
        if matches.count > 0
          # if we got this far then we have a match in our local cache
          # lets see if we can find a description
          url = "http://searchvu.vanderbilt.edu/search?as_epq=#{CGI.escape(v)}+mutation&client=mycancergenome"
          xml = Nokogiri::XML(Scrapers::Util.make_get_request(url)) 
          url = xml.xpath("/GSP/RES[1]/R[1]/U[1]").text
          if !url.blank?
            xml = Nokogiri::XML(Scrapers::Util.make_get_request(url)) 
            description = xml.xpath('//*[@id="section-content-container"]/div[3]//p[1]').text
            description << "#{url}"
            description.gsub!("\n", " ")  if !description.blank?
            return description if !description.blank?
          end
        else
          puts "#{v} not found in cosmic AA variants"
        end
      }
      nil
    end  

    def cosmic_variants
      @@cosmic_variants
    end  

    # civic genes need entrez ids, also need description, fetch them
    def to_civic_gene
      # per Obi Griffith (ps these genes don't exist in Rodrigo > 7.0)
      self.gene_name = "KMT2A" if self.gene_name == "MLL" 
      self.gene_name = "MLH1" if self.gene_name == "MSH1"
      #            
      
      # Gene named AR-V7 not found!
     #  Gene named BCR-ABL1 not found!
     #  Gene named BCR-ABL1 not found!
     #  Gene named BCR-ABL1 not found!
     #  Gene named BCR-ABL1 not found!
     #  Gene named BCR-JAK2 not found!
     #  Gene named COL1A1-PDGFRB not found!
     #  Gene named INI1 not found!
     #  Gene named PML-RARA not found!
     #  Gene named RET-PTC1 not found!
     #  Gene named RET-PTC1 not found!   
     self.gene_name = "INI1" if self.gene_name == "SMARCB1"
     puts(self.gene_name)
     if (self.gene_name && self.gene_name.index("-") ) 
       self.gene_name = gene_name.split("-")[0] 
     end

      
      gene = ::Gene.find_or_initialize_by(name: gene_name )
      if gene.new_record?
        (gene.entrez_id,gene.official_name,aliases,sources) = get_genenames_info(gene_name)
        gene.entrez_id = -1 unless gene.entrez_id
        gene.entrez_id = -1 if gene.entrez_id==0
        gene.official_name = description unless gene.official_name
        aliases = [gene.name] unless aliases
        gene.gene_aliases  = aliases.map {|a| GeneAlias.find_or_create_by(name: a ) } if aliases
        (gene.description,) = get_mygene_info_by_entrez_id(gene.entrez_id)
        gene.description = "N/A" unless gene.description
        sources.each {|pubmed_id| gene.sources << Source.find_or_initialize_by(:pubmed_id => pubmed_id)}   if sources     
      end
      self.civic_gene = gene
    end    

    def singularize(str)
      str.split(' ').map {|s| s.singularize} .join(' ')
    end

#<Importer::Row gene_name="ABL1", disease_name="ALL", variant_name="T315A", description="missense mutation", effect="gain-of-function", association="response", drug="nilotinib, ponatinib", status="NCCN guidelines", evidence="consensus", pubmed_id="NCCN">


    def to_civic_evidence
      evidence_item = ::EvidenceItem.new 

      # set up the chain to from Gene->Variant->evidence

      variant = ::Variant.find_or_initialize_by(:name => variant_name)
      if variant.new_record?
        puts ">>>>> new variant"
        variant.gene = to_civic_gene
        variant.description = fetch_variant_description(variant_name) 
        variant.description =  variant.description ? variant.description : "Click edit to complete variant description" 
      else
        puts ">>>>> existing variant #{variant}"
      end
      evidence_item.variant = variant
      evidence_item.variant_hgvs = "N/A"

      evidence_item.disease =  to_civic_disease
      
      evidence_item.description = "OHSU Import; "
      evidence_item.description << "#{description}; " 

      ## existing in CIVIC
      # ["Positive",
      #  "Sensitivity",
      #  "Resistance or Non-Response",
      #  "Poor Outcome",
      #  "N / A",
      #  "Negative",
      #  "Better Outcome"]
      ## in Rodrigo association
      # ["response",
      #  nil,
      #  "sensitivity",
      #  "resistance",
      #  "reduced sensitivity",
      #  "no response",
      #  "decreased sensitivity",
      #  "increased benefit",
      #  "no sensitivity"]
      clinical_significance_map = {  
        "response"=>"Positive",
        nil=>"N/A",
        "sensitivity"=>"Sensitivity",
        "resistance"=>"Resistance or Non-Response",
        "reduced sensitivity"=>"Negative",
        "no response"=>"Resistance or Non-Response",
        "decreased sensitivity"=>"Negative",
        "increased benefit"=>"Positive",
        "no sensitivity"=>"Resistance or Non-Response"   
      }
      evidence_item.clinical_significance = clinical_significance_map[ association ]
      evidence_item.description << "#{association}; " 

      evidence_item.drugs << drug.split(',').map{|n| to_civic_drug(n.strip)}


      # TODO - loss of fidelity - CIViC "belongs to", CGD "has many"
      if source
        evidence_item.source = Source.find_or_initialize_by(:pubmed_id => pubmed_id)   if pubmed_id
      else  
        evidence_item.source = ::Source.find_or_initialize_by(:description => "OHSU Rodrigo", :pubmed_id => "N/A")
      end

      # evidence direction
      # ["Does Not Support","Supports"]
      ## in Rodrigo  effect
      # ["gain-of-function",
      #  "loss-of-function",
      #  "reduced kinase activity",
      #  "gain-of-function (low activity)",
      #  "switch-of-function",
      #  "not applicable"]
      evidence_item.evidence_direction = "Supports" # effect.blank? ? "N/A" : effect ;
      evidence_item.description << "#{effect}; " 




      ## evidence_types
      #["Diagnostic", "Predictive", "Prognostic"]
      ## in Rodrigo  evidence
      # ["consensus", "emerging", "", nil]
      # TODO
      # evidence_item.evidence_type =  EvidenceType.find_or_initialize_by(:evidence_type => !evidence.blank? ? evidence : "N/A")
      evidence_item.description << "#{evidence}; " 

      #  evidence level
      # "A" validated
      # "B" clinical
      # "C" preclinical
      # "D" inferential
      ## in Rodrigo  status
      # ["NCCN guidelines",
      #  "case report",
      #  "preclinical",
      #  "FDA-approved",
      #  "early trials",
      #  "late trials",
      #  "NCCN/ CAP guidelines",
      #  "",
      #  "FDA-rejected",
      #  "early trials, case report",
      #  "late trials, preclinical"]

      evidence_level_map = {
        "NCCN guidelines" => "A" ,
        "case report" => "B",
        "preclinical" => "B",
        "FDA-approved" => "A",
        "early trials" => "C",
        "late trials" => "C",
        "NCCN/ CAP guidelines" => "A",
        "" => "D",
        nil => "D",
        "FDA-rejected" => "D",
        "early trials, case report" => "C", 
        "late trials, preclinical" => "C" 
      }
      evidence_item.evidence_level = evidence_level_map[ status ]
      evidence_item.description << "#{status}; " 
      

      # TODO - evidence type
      # ["Diagnostic","Predictive","Prognostic"]
      #expand from: CGD::therapeutic_association      
      

      # TODO - variant origin
      # Somatic mutations are not transmitted to progeny, but germinal mutations may be transmitted to some or all progeny.
      # ["Somatic","Germline"]

      evidence_item
    end  


    def to_civic_disease
      disease = ::Disease.find_or_initialize_by(:name => disease_name ) 
      if !disease.doid
        options={"Accept" => 'application/json', "Authorization" => "apikey token=fb76114e-2eff-4a05-9a2e-eba5b9fb6f0e"}
        # look for exact match
        url = "http://data.bioontology.org/search?q=#{CGI.escape(disease_name)}&require_exact_match=true&ontologies=DOID&include=prefLabel,synonym,definition,notation"
        response = JSON.parse(make_get_request(url,options))
        # sigularize look for in exact match
        if response['collection'].length == 0
          url = "http://data.bioontology.org/search?q=#{CGI.escape(singularize(disease_name))}&require_exact_match=false&ontologies=DOID&include=prefLabel,synonym,definition,notation"
          response = JSON.parse(make_get_request(url,options))   
        end    
        # grab "DOID:id"
        disease.doid = response['collection'][0]['notation'].split(':')[1] if response['collection'].length > 0    
        disease.doid = "N/A" unless disease.doid 
      end
      unknown_disease  unless disease
      disease  if  disease
    end  

    def to_civic_drug(drug_name)
      drug = ::Drug.find_or_initialize_by(:name => drug_name ) 
      if !drug.pubchem_id
        # look for exact match
        url = "http://pubchem.ncbi.nlm.nih.gov/rest/pug/compound/name/#{CGI.escape(drug_name)}/cids/json"
        response = JSON.parse(make_get_request(url,{"Accept" => '*/*'},false))
        drug.pubchem_id = response['IdentifierList']['CID'].first if response['IdentifierList'] && response['IdentifierList']['CID']
        drug.pubchem_id = "N/A" unless drug.pubchem_id 
      end
      drug
    end     

        
    private # --------------------
    def unknown_disease
      disease = ::Disease.find_or_initialize_by(:name => "Unknown" ) 
      disease.doid = "N/A" unless disease.doid 
      disease
    end  

    def make_get_request(url,options={"Accept" => 'application/json'},debug=false)
      uri = URI(URI.encode(url))      
      req = Net::HTTP::Get.new(uri)
      # req has hash semantics but no merge! 
      options.keys.each {|k| req[k] = options[k]} if options
      if (debug)    
        puts "Request: #{uri}"
        puts "Request: #{req.to_hash.inspect}"
      end
      res = Net::HTTP.start(uri.hostname, uri.port) {|http|
        http.request(req)
      }
      if (debug)    
        puts "Response: #{res.to_hash.inspect}"
        puts "Response: #{res.code}"
        puts "Response: #{res.body}"
      end
      raise "#{res.body} #{uri}" unless (res.code == '200' || res.code == '404' )
      return "{}" if  res.code == '404'
      res.body
    end 
    def get_genenames_info(symbol)
      response = make_get_request("http://rest.genenames.org/fetch/symbol/#{symbol}")
      response = JSON.parse(response)
      doc = response['response']['docs'][0]
      doc = {} unless doc
      [doc['entrez_id'],doc['name'],doc['alias_symbol'],doc['pubmed_id']]
    end
    def get_mygene_info_by_entrez_id(entrez_id)
      response = make_get_request("http://mygene.info/v2/gene/#{entrez_id}")
      response = JSON.parse(response)
      [response['summary']]
    end    
  end


  def initialize
    path =  File.join(__dir__, 'Knowledge_database_v12.0.txt')
    @parsed_file = CSV.read(path, { :col_sep => "\t",:headers => true,:encoding => 'ISO-8859-1' })
    @evidence = parsed_file.map do |r|
      (1..8).map {|i| 
        i if !r["Status_#{i}"].nil? 
      }.compact.map do |i| 
        Row.new({
         :gene_name => r['Gene'].strip , 
         :disease_name => r['Disease'].strip ,
         :variant_name => r['Variant'].strip ,
         :description => r['Description'].strip ,
         :effect => r['Effect'].strip ,
         :association => r["Association_#{i}"] ? r["Association_#{i}"].strip : nil ,
         :drug => r["Therapeutic context_#{i}"] ? r["Therapeutic context_#{i}"].strip : nil ,
         :status => r["Status_#{i}"] ? r["Status_#{i}"].strip : nil ,
         :evidence => r["Evidence_#{i}"] ? r["Evidence_#{i}"].strip : nil ,
         :pubmed_id => r["PMID_#{i}"] ? r["PMID_#{i}"].strip : nil 
         })
      end  
    end.flatten     

  end

  def export(last_gene_id, last_variant_id,last_evidence_item_id)
    genes = []
    variants = []
    evidence = []
    @evidence.each {|e| 
      ei = e.to_civic_evidence
      ei.save! 
      evidence << ei.to_tsv if ei.id > last_evidence_item_id
      ei.variant.save! if !ei.variant.id
      variants << ei.variant.to_tsv if ei.variant.id > last_variant_id
      ei.variant.gene.save! if !ei.variant.gene.id
      genes << ei.variant.gene.to_tsv if ei.variant.gene.id > last_gene_id
    }

   File.open("import/ohsu-GeneSummaries.txt", 'w') { |file| 
     file.write("entrez_gene\tSummary\tSources\n")
     genes.each {|g| file.write(g) }
   } 

   File.open("import/ohsu-VariantSummaries.txt", 'w') { |file| 
     file.write("entrez_gene\tvariant\tSummary\n")
     variants.each {|v| file.write(v) }
   }

   File.open("import/ohsu-ClinActionEvidence.txt", 'w') { |file| 
     file.write("entrez_gene\tentrez_id\tvariant\tvariant_hgvs\tvariant_origin\tDisease\tDOID\tDrug\tpubchem_id\tEvidence Type\tEvidence Direction\tClinical Significance\tStatement\tLevel\tSource\tText\tType of study\tComments\tCurator\tstars\tInclude?\tVariant Group\t\n")
     evidence.each {|e| file.write(e) }
   }

   File.open("import/ohsu-VariantGroupSummaries.txt", 'w') { |file| 
     file.write("Variant_Group\tSummary\n") 
   }            
   "done"
  end
  

  def with_multiple_variants
    @evidence.map {|e| e if e.variant_name.include?("/")}.compact
  end




end


# inject mix-in methods to CIViC classes to help us create tsv files
class Gene
  #inject a mix-in we will use to create an import file. [entrez_gene, Summary, Sources]
  def to_tsv(separator = "\t")
    pubmed_ids = []
    sources.each {|s| pubmed_ids << s.pubmed_id} if sources
    "#{name}#{separator}#{description}#{separator}#{pubmed_ids.join(',')}\n"
  end     
end

class Variant
  # [entrez_gene variant Summary]
  def to_tsv(separator = "\t")
    "#{gene.name}#{separator}#{name}#{separator}#{description}\n"
  end     
end 


class EvidenceItem
  # [entrez_gene  entrez_id variant variant_hgvs  variant_origin  Disease DOID  Drug  pubchem_id  Evidence Type Evidence Direction  Clinical Significance Statement Level Source  Text  Type of study Comments  Curator stars Include?  Variant Group]
  def to_tsv(separator = "\t")
    tsv = ""
    drugs.each { |drug|
      tsv << "#{variant.gene.name}#{separator}"    # entrez_gene
      tsv << "#{variant.gene.entrez_id}#{separator}"  # entrez_id  
      tsv << "#{variant.name}#{separator}"    # variant
      tsv << "#{variant_hgvs}#{separator}"     # variant_hgvs
      tsv << "#{variant_origin}#{separator}"    # variant_origin
      tsv << "#{disease.name}#{separator}"    # Disease
      tsv << "#{disease.doid}#{separator}"    # DOID
      tsv << "#{drug.name}#{separator}"    # Drug
      tsv << "#{drug.pubchem_id}#{separator}"    # pubchem_id

      tsv << "#{evidence_type}#{separator}"    # Evidence Type
      tsv << "#{evidence_direction}#{separator}"    # Evidence Direction
      tsv << "#{clinical_significance}#{separator}"   # Clinical Significance
      tsv << "#{description}#{separator}"    # Statement
      tsv << "#{evidence_level}#{separator}"     #Level
      tsv << "#{source.pubmed_id}#{separator}"     #Source
       tsv << "#{separator}"     #Text
       tsv << "#{separator}"     #Type of study
       tsv << "#{separator}"     #Comments
       tsv << "#{separator}"     #Curator
       tsv << "#{separator}"     #stars
       tsv << "1#{separator}"     #Include?
       tsv << "#{separator}"     #Variant Group

      #Source Text  Type of study Comments  Curator stars Include?  Variant Group
      tsv << "#{separator}#{separator}N/A#{separator}#{separator}#{separator}#{separator}#{separator}#{separator}1#{separator}"    
      tsv << "\n"
    }
    tsv
  end     
end 
