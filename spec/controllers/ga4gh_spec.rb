require 'rails_helper'

describe Ga4ghBeaconController do
  
  it 'should show information about the beacon' do    
    (1..10).each {|i| v = Fabricate(:variant, chromosome: "chr-#{i}") }
    
    get :index 
    beacon = JSON.parse(response.body)
    expect(beacon["data_size_resource"]["variants"] ).to eq Variant.where.not(:chromosome => nil ).count
    expect(beacon["data_size_resource"]["samples"] ).to eq Variant.count
  end

  it 'should return a beacon for a known genomic location' do    
    (1..10).each {|i| v = Fabricate(:variant, chromosome: "chr-#{i}", start: i,  reference_bases: "A" ) }         

    get :show , chrom: "chr-1", pos: 1, allele: "A" 
    body = JSON.parse(response.body)
    expect(response.status).to eq(200) , "expected response.status to be 200"
    expect(body["beacon"]).to be_truthy , "expected body.beacon to be non null" 
    expect(body["response"]["exists"]).to be_truthy , "expected body.response.exists to be true" 
  end

  it 'should return a beacon with no find for a unknown genomic location' do    
    (1..10).each {|i| v = Fabricate(:variant, chromosome: "chr-#{i}", start: i,  reference_bases: "A" ) }         

    get :show , chrom: "chr-Z", pos: 3, allele: "Z" 
    body = JSON.parse(response.body)
    expect(response.status).to eq(404) , "expected response.status to be 404"
    expect(body["beacon"]).to be_truthy , "expected body.beacon to be non null" 
    expect(body["response"]["exists"]).to be_falsey , "expected body.response.exists to be false" 
  end


end



