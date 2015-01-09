require 'spec_helper'
describe 'sourcebans' do

  context 'with defaults for all parameters' do
    it { should contain_class('sourcebans') }
  end
end
