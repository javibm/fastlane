describe Gym::CodeSigningMapping do
  describe "#app_identifier_contains?" do
    it "returns false if it doesn't contain it" do
      csm = Gym::CodeSigningMapping.new(project: nil)
      return_value = csm.app_identifier_contains?("dsfsdsdf", "somethingelse")
      expect(return_value).to eq(false)
    end

    it "returns true if it doesn't contain it" do
      csm = Gym::CodeSigningMapping.new(project: nil)
      return_value = csm.app_identifier_contains?("FuLL-StRing Yo", "fullstringyo")
      expect(return_value).to eq(true)
    end

    it "Strips out all the usual characters that are not needed" do
      csm = Gym::CodeSigningMapping.new(project: nil)
      return_value = csm.app_identifier_contains?("Ad-HocValue", "ad-hoc")
      expect(return_value).to eq(true)
    end

    it "Replace the inhouse keyword for enterprise profiles" do
      csm = Gym::CodeSigningMapping.new(project: nil)
      return_value = csm.app_identifier_contains?("match InHouse bundle", "enterprise")
      expect(return_value).to eq(true)
    end
  end

  describe "#detect_project_profile_mapping" do
    it "returns the mapping of the selected provisioning profiles" do
      workspace_path = "gym/spec/fixtures/projects/cocoapods/Example.xcworkspace"
      project = FastlaneCore::Project.new({
        workspace: workspace_path
      })
      csm = Gym::CodeSigningMapping.new(project: project)
      expect(csm.detect_project_profile_mapping).to eq({ "family.wwdc.app" => "match AppStore family.wwdc.app", "family.wwdc.app.watchkitapp" => "match AppStore family.wwdc.app.watchkitapp", "family.wwdc.app.watchkitapp.watchkitextension" => "match AppStore family.wwdc.app.watchkitappextension" })
    end
  end

  describe "#detect_project_profile_mapping_for_tv_os" do
    it "returns the mapping of the selected provisioning profiles for tv_os" do
      workspace_path = "gym/spec/fixtures/projects/cocoapods/Example.xcworkspace"
      project = FastlaneCore::Project.new({
        workspace: workspace_path
      })
      csm = Gym::CodeSigningMapping.new(project: project)
      Gym.config[:destination] = "generic/platform=tvOS"
      expect(csm.detect_project_profile_mapping).to eq({ "family.wwdc.app" => "match AppStore family.wwdc.app.tvos" })
    end
  end

  describe "#merge_profile_mapping" do
    let (:csm) { Gym::CodeSigningMapping.new }

    it "only mapping from Xcode Project is available" do
      result = csm.merge_profile_mapping(primary_mapping: {},
                                       secondary_mapping: { "identifier.1" => "value.1" },
                                           export_method: "app-store")

      expect(result).to eq({ :"identifier.1" => "value.1" })
    end

    it "only mapping from match (user) is available" do
      result = csm.merge_profile_mapping(primary_mapping: { "identifier.1" => "value.1" },
                                       secondary_mapping: {},
                                           export_method: "app-store")

      expect(result).to eq({ :"identifier.1" => "value.1" })
    end

    it "keeps both profiles if they don't conflict" do
      result = csm.merge_profile_mapping(primary_mapping: { "identifier.1" => "value.1" },
                                       secondary_mapping: { "identifier.2" => "value.2" },
                                           export_method: "app-store")

      expect(result).to eq({ :"identifier.1" => "value.1", :"identifier.2" => "value.2" })
    end

    it "doesn't crash if nil is provided" do
      result = csm.merge_profile_mapping(primary_mapping: nil,
                                       secondary_mapping: {},
                                           export_method: "app-store")
      expect(result).to eq({})
    end

    it "accesses the Xcode profile mapping, if nothing else is given" do
      expect(csm).to receive(:detect_project_profile_mapping).and_return({ "identifier.1" => "value.1" })
      result = csm.merge_profile_mapping(primary_mapping: {}, export_method: "app-store")

      expect(result).to eq({ :"identifier.1" => "value.1" })
    end

    describe "handle conflicts" do
      it "Both primary and secondary are available, and both match the export method, it should prefer the primary mapping" do
        result = csm.merge_profile_mapping(primary_mapping: { "identifier.1" => "Ap-pStoreValue2" },
                                       secondary_mapping: { "identifier.1" => "Ap-pStoreValue1" },
                                           export_method: "app-store")

        expect(result).to eq({ :"identifier.1" => "Ap-pStoreValue2" })
      end

      it "Both primary and secondary are available, and the secondary is the only one that matches the export type" do
        result = csm.merge_profile_mapping(primary_mapping: { "identifier.1" => "Ap-p StoreValue1" },
                                       secondary_mapping: { "identifier.1" => "Ad-HocValue" },
                                           export_method: "app-store")

        expect(result).to eq({ :"identifier.1" => "Ap-p StoreValue1" })
      end

      it "Both primary and secondary are available, and the seocndary is the only one that matches the export type" do
        result = csm.merge_profile_mapping(primary_mapping: { "identifier.1" => "Ap-p StoreValue1" },
                                       secondary_mapping: { "identifier.1" => "Ad-HocValue" },
                                           export_method: "ad-hoc")

        expect(result).to eq({ :"identifier.1" => "Ad-HocValue" })
      end

      it "both primary and secondary are available, and neither of them match the export type, it should choose the secondary_mapping" do
        result = csm.merge_profile_mapping(primary_mapping: { "identifier.1" => "AppStore" },
                                       secondary_mapping: { "identifier.1" => "Adhoc" },
                                           export_method: "development")

        expect(result).to eq({ :"identifier.1" => "Adhoc" })
      end

      context "when both primary and secondary are available and same value" do
        let(:result) do
          csm.merge_profile_mapping(primary_mapping: { primary_key => "AppStore" },
                                    secondary_mapping: { secondary_key => "AppStore" },
                                    export_method: "development")
        end
        context "when primary's key is symbol and secondary's key is also symbol" do
          let(:primary_key) { :"identifier.1" }
          let(:secondary_key) { :"identifier.1" }
          it "is merged correctly" do
            expect(result).to eq({ :"identifier.1" => "AppStore" })
          end
        end
        context "when primary's key is symbol and secondary's key is string" do
          let(:primary_key) { :"identifier.1" }
          let(:secondary_key) { "identifier.1" }
          it "is merged correctly" do
            expect(result).to eq({ :"identifier.1" => "AppStore" })
          end
        end
        context "when primary's key is string and secondary's key is also string" do
          let(:primary_key) { "identifier.1" }
          let(:secondary_key) { "identifier.1" }
          it "is merged correctly" do
            expect(result).to eq({ :"identifier.1" => "AppStore" })
          end
        end
        context "when primary's key is string and secondary's key is also symbol" do
          let(:primary_key) { "identifier.1" }
          let(:secondary_key) { :"identifier.1" }
          it "is merged correctly" do
            expect(result).to eq({ :"identifier.1" => "AppStore" })
          end
        end
      end
    end

    describe "#test_target?" do
      let(:csm) { Gym::CodeSigningMapping.new(project: nil) }
      context "when build_setting include TEST_TARGET_NAME" do
        it "is test target" do
          build_settings = { "TEST_TARGET_NAME" => "Sample" }
          expect(csm.test_target?(build_settings)).to be true
        end
      end
      context "when build_setting include TEST_HOST" do
        it "is test target" do
          build_settings = { "TEST_HOST" => "Sample" }
          expect(csm.test_target?(build_settings)).to be true
        end
      end
      context "when build_setting include neither TEST_HOST nor TEST_TARGET_NAME" do
        it "is not test target" do
          build_settings = {}
          expect(csm.test_target?(build_settings)).to be false
        end
      end
    end
  end
end
