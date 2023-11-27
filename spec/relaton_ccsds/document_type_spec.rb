describe RelatonCcsds::DocumentType do
  it "with correct doctype" do
    expect do
      described_class.new type: "record"
    end.not_to output(/WARNING/).to_stderr
  end

  # it "with incorrect doctype" do
  #   expect do
  #     described_class.new type: "spec"
  #   end.to output("[relaton-ccsd] WARNING: Invalid doctype: `spec`\n").to_stderr
  # end
end
