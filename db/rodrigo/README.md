#Running CGD import



### start from initialized db

```
rake db:drop db:create db:schema:load 
rake  civic:import['import/GeneSummaries.txt','import/VariantSummaries.txt','import/ClinActionEvidence.txt','import/VariantGroupSummaries.txt']

```

### load rodrigo importer

```ruby
# load importer
load 'db/rodrigo/importer.rb'
i = Importer.new ; nil

# remember last data 
last_gene_id = Gene.last.id
last_variant_id = Variant.last.id
last_evidence_item_id = EvidenceItem.last.id

#[31] pry(main)> last_gene_id
#=> 63
#[32] pry(main)> last_variant_id
#=> 164
#[33] pry(main)> last_evidence_item_id
#=> 431
# export data 
i.export(last_gene_id,last_variant_id,last_evidence_item_id)

# clean up database
EvidenceItem.where("id > ?",last_evidence_item_id ).each {|ei| ei.drugs.clear ; ei.destroy } ; nil
Variant.where("id > ?",last_variant_id ).delete_all
Gene.where("id > ?",last_gene_id ).delete_all
```



## From MYSQL database
### mysql
```
Install mysql and load the g2p.sql dump file. See mysql documentation for your system.
```

### update your gem file
```
gem 'mysql2' # ohsu import-cgd

``

### alter local database.yml as necessary
```
cgd_development:
  adapter: mysql2
  host: localhost
  database: g2p

``

### run the import
```
rails r "load 'db/import-cgd/importer.rb';puts(CGD::TherapyVariant.migrate_all_to_civic)" 
```

### examine outputs
```
 [["Entity,CIViC,CGD,",
  "Gene,53,93",
  "Variant,132,445",
  "Evidence,409,1106",
  "Drug,68,154",
  "Disease,39,51",
  "Source,190,339"],
 ["Entity,CIViC,CGD,Common",
  "Unique Sources,161,310,29",
  "Unique Diseases,28,40,11",
  "Unique Drugs,66,152,2",
  "Unique Variants,132,445,0",
  "Unique Genes,53,93,42"]]
```


### at this point, files are ready for distribution

```
rake  civic:import['import/ohsu-GeneSummaries.txt','import/ohsu-VariantSummaries.txt','import/ohsu-ClinActionEvidence.txt','import/ohsu-VariantGroupSummaries.txt']

```