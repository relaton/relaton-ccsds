describe RelatonCcsds::Util do
  it "#logger" do
    expect(described_class.logger).to be_instance_of Logger
  end
end
