require_relative 'test_helper'
require 'time'

describe SimpleXlsxReader do
  let(:sesame_street_blog_file) { File.join(File.dirname(__FILE__),
                                            'sesame_street_blog.xlsx') }

  let(:subject) { SimpleXlsxReader::Document.new(sesame_street_blog_file) }

  describe '#to_hash' do
    it 'reads an xlsx file into a hash of {[sheet name] => [data]}' do
      subject.to_hash.must_equal({
        "Authors"=>
          [["Name", "Occupation"],
           ["Big Bird", "Teacher"]],

        "Posts"=>
          [["Author Name", "Title", "Body", "Created At", "Comment Count"],
           ["Big Bird", "The Number 1", "The Greatest", Time.parse("2002-01-01 11:00:00 UTC"), 1],
           ["Big Bird", "The Number 2", "Second Best", Time.parse("2002-01-02 14:00:00 UTC"), 2]]
      })
    end
  end

  describe SimpleXlsxReader::Document::Mapper do
    let(:described_class) { SimpleXlsxReader::Document::Mapper }

    describe '::cast' do
      it 'reads type s as a shared string' do
        described_class.cast('1', 's', shared_strings: ['a', 'b', 'c']).
          must_equal 'b'
      end

      it 'reads type inlineStr as a string' do
        xml = Nokogiri::XML(%( <c t="inlineStr"><is><t>the value</t></is></c> ))
        described_class.cast(xml.text, 'inlineStr').must_equal 'the value'
      end
    end

    describe '#shared_strings' do
      let(:xml) do
        SimpleXlsxReader::Document::Xml.new.tap do |xml|
          xml.shared_strings = Nokogiri::XML(File.read(
            File.join(File.dirname(__FILE__), 'shared_strings.xml') ))
        end
      end

      subject { described_class.new(xml) }

      it 'parses strings formatted at the cell level' do
        subject.shared_strings[0..2].must_equal ['Cell A1', 'Cell B1', 'My Cell']
      end

      it 'parses strings formatted at the character level' do
        subject.shared_strings[3..5].must_equal ['Cell A2', 'Cell B2', 'Cell Fmt']
      end
    end

    describe "parse errors" do
      after do
        SimpleXlsxReader.configuration.catch_cell_load_errors = false
      end

      let(:xml) do
        SimpleXlsxReader::Document::Xml.new.tap do |xml|
          xml.sheets = [Nokogiri::XML(
            <<-XML
            <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
              <sheetData>
                <row>
                  <c s='0'>
                    <v>14 is a date style; this is not a date</v>
                  </c>
                </row>
              </sheetData>
            </worksheet>
            XML
          )]

          # s='0' above refers to the value of numFmtId at cellXfs index 0
          xml.styles = Nokogiri::XML(
            <<-XML
            <styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
              <cellXfs count="1">
                <xf numFmtId="14" />
              </cellXfs>
            </styleSheet>
            XML
          )
        end
      end

      it 'raises if configuration.raise_on_parse_error' do
        SimpleXlsxReader.configuration.catch_cell_load_errors = false

        lambda { described_class.new(xml).parse_sheet('test', xml.sheets.first) }.
          must_raise(SimpleXlsxReader::CellLoadError)
      end

      it 'records a load error if not configuration.raise_on_parse_error' do
        SimpleXlsxReader.configuration.catch_cell_load_errors = true

        sheet = described_class.new(xml).parse_sheet('test', xml.sheets.first)
        sheet.load_errors[[0,0]].must_include 'invalid value for Integer'
      end
    end
  end
end
