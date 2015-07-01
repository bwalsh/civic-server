class Ga4ghBeaconController < ApplicationController

  actions_without_auth :index, :show
  before_action :initialize_beacon


  def index
    render json: @@beacon
  end


  def show
    # parse query
    chromosome = params[:chrom]
    position = params[:pos].to_i
    allele = params[:allele]
    reference = params[:ref]
    reference = "HG19" unless reference
    dataset = params[:dataset]  
    dataset = @@beacon["datasets"][0]["id"] unless dataset  
    

    query = {
        'chromosome': chromosome,
        'position': position,
        'allele': allele,
        'reference': reference,
        'dataset_id': dataset
    }
              
    #
    if query[:chromosome] && query[:position] && query[:allele] && query[:reference]

      #
      # #--------------------------------------------------------------#
      #     # generate response
      variant_count = Variant.where(chromosome: query[:chromosome],  start: query[:position],  reference_bases: query[:allele] ).count
      genomic_variant_count = Variant.where.not(chromosome: nil ).count
      if (variant_count) 
        variant = Variant.where(chromosome: query[:chromosome],  start: query[:position],  reference_bases: query[:allele] ).first
      end  
      #
      # ############## AlleleResource for response ###############
      #
      #     # required field(s): allele
      allele_resource = {
        'allele': query[:allele],
        # Frequency of this allele in the dataset. Between 0 and 1, inclusive. 
        'frequency': variant_count == 0 ? 0 : (variant_count.to_f  / genomic_variant_count).round(2) 
      }

      #     # required field(s): exists
      response = {
        # Whether the beacon has observed variants. True if an observation exactly matches request. Overlap if an observation overlaps request, but not exactly, as in the case of indels or if the query used wildcard for allele. False if data are present at the requested position but no observations exactly match or overlap. Null otherwise. */
          'exists': variant_count > 0,
          # Number of observations of this allele in the dataset
          'observed': variant_count,  # integer, min 0
          'alleles': [
              allele_resource
          ],
          'info': variant ? "evidence items (#{variant.evidence_items.length})" : "not found"  
      }
      #


      #
      #     return jsonify({ "beacon" : beacon['id'], "query" : query, "response" : response })

      render json: { "beacon": @@beacon["id"], "query": query, "response": response } , status: variant_count > 0 ? 200 : 404 

    else 
      #
      # ############# ErrorResource for response #################
      #
      #     # required field(s): name
      error_resource = { } 
      error_resource[:description] = 'Required parameters are missing'
      error_resource[:name] = 'Incomplete Query'
      error_payload = {
        'beacon': @@beacon[:id],
        'query': query,
        'error': error_resource        
      }
      
      render json: error_payload, status: 410 
    end 
    

    
    # puts "response=#{@response}"
    # render json: @response
  end


  private
  @@beacon = nil 
  def initialize_beacon
    return if @@beacon
    
    #load beacon configuration from /config
    config = YAML.load(File.open("#{Rails.root}/config/ga4gh.yml", 'r'))

    # required field(s): variants
    config["beacon"]["data_size_resource"] = {
      #/** Total number of variant positions in the data set */
      'variants': Variant.where.not(:chromosome => nil ).count , # integer
      #/** Total number of samples in the data set */
      'samples': Variant.count # integer
    }
    @@beacon = config["beacon"]
    #
    #
    # ########### data_set_resource for beacon details ############
    #
    # # required field(s): name
    # data_use_requirement_resource = {
    #   #/** Data Use requirement.*/
    #   'name': 'evidence',
    #   #/** Description of Data Use requirement. */
    #   'description': 'evidence maintained in CIViC'
    # }
    #
    #
    # # required field(s): category
    # data_use_resource = {
    #     'category': 'public',
    #     'description': 'no protected health information',
    #     'requirements': [
    #         data_use_requirement_resource
    #     ]
    # }
    #
    # # required field(s): id
    # data_set_resource = {
    #     'id': 'civic.genome.wustl.edu',
    #     'description': 'Variants, drugs and diseases',
    #     'reference': 'HG19', # TODO-check',
    #     'size': data_size_resource,  # Dimensions of the data set (required if the beacon reports allele frequencies)
    #     'data_uses': [
    #         data_use_resource # data_ use limitations
    #     ]
    # }
    #
    # ########### query_resource for beacon details ###############
    #
    # # required field(s): allele, chromosome, position, reference
    # query_resource = {
    #     'allele': 'C',
    #     'chromosome': '14',
    #     'position': 105246551, # integer
    #     'reference': data_set_resource[:reference],
    #     'dataset_id': data_set_resource[:id]
    #
    #     # chromosome: "14",
    #     # start: "105246551",
    #     # stop: "105246551",
    #     # reference_bases: "C",
    #     # variant_bases: "T",
    # }
    #
    # ################### Beacon details #########################
    #
    # # required field(s): id, name, organization, api
    # @@beacon = {
    #     'id': 'civic.genome.wustl.edu',
    #     'name': 'Washington University',
    #     'organization': "#{request.host}",
    #     'api': '0.2',
    #     'description': 'beacon description',
    #     'datasets': [
    #         data_set_resource  # data_sets served by the beacon
    #     ],
    #     'homepage': request.url,
    #     'email': "beacon@#{request.host}",
    #     'auth': 'none',  # OAUTH2, defaults to none
    #     'queries': [
    #         query_resource  # Examples of interesting queries
    #     ]
    # }
  end

end