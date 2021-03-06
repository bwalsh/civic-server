require 'rails_helper'

describe GeneCommentsController do
  it 'should allow for "meta" subscriptions to class/action combinations' do
    user = Fabricate(:user)
    gene = Fabricate(:gene)
    OnSiteSubscription.create(user: user, action_type: 'commented', action_class: 'Gene')
    controller.sign_in(user)

    post :create, gene_id: gene.id, text: 'test text', title: 'test title'

    expect(gene.comments.count).to eq 1
    expect(Delayed::Worker.new.work_off).to eq [1,0]
    expect(Event.count).to eq 1
    expect(Feed.for_user(user).count).to eq 1
  end

  it 'should allow for direct subscriptions to "subscribables"' do
    user = Fabricate(:user)
    gene = Fabricate(:gene)
    OnSiteSubscription.create(user: user, subscribable: gene)
    controller.sign_in(user)

    post :create, gene_id: gene.id, text: 'test text', title: 'test title'

    expect(gene.comments.count).to eq 1
    expect(Delayed::Worker.new.work_off).to eq [1,0]
    expect(Event.count).to eq 1
    expect(Feed.for_user(user).count).to eq 1
  end
end

describe EvidenceItemCommentsController do
  it 'should traverse the hierarchy of subscribables' do
    user = Fabricate(:user)
    gene = Fabricate(:gene)
    variant = Fabricate(:variant, gene: gene)
    evidence_item = Fabricate(:evidence_item, variant: variant)
    OnSiteSubscription.create(user: user, subscribable: gene)
    controller.sign_in(user)

    post :create, evidence_item_id: evidence_item.id, text: 'test text', title: 'test title'

    expect(evidence_item.comments.count).to eq 1
    expect(Delayed::Worker.new.work_off).to eq [1,0]
    expect(Event.count).to eq 1
    expect(Feed.for_user(user).count).to eq 1
  end

  it 'should only send a single notification for a single event (de-dup subscriptions)' do
    user = Fabricate(:user)
    gene = Fabricate(:gene)
    variant = Fabricate(:variant, gene: gene)
    evidence_item = Fabricate(:evidence_item, variant: variant)
    OnSiteSubscription.create(user: user, subscribable: gene)
    OnSiteSubscription.create(user: user, subscribable: evidence_item)
    OnSiteSubscription.create(user: user, action_type: 'commented', action_class: 'Gene')
    controller.sign_in(user)

    post :create, evidence_item_id: evidence_item.id, text: 'test text', title: 'test title'

    expect(evidence_item.comments.count).to eq 1
    expect(Delayed::Worker.new.work_off).to eq [1,0]
    expect(Event.count).to eq 1
    expect(Feed.for_user(user).count).to eq 1
  end
end
