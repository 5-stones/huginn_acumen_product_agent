# AcumenProductAgent

The Huginn ACUMEN Product Agent takes in an array of ACUMEN product ID's, queries the relevant ACUMEN tables, and emits a set of events with a sane data interface for each those events.

Here's the data interface:

```ts
interface Product {
  name: string;
  subtitle: string;
  description: string;
  editorialReviews: string;
  variants: Variant[];
  categories: number[];
  contributors: ProductContributor[];
}

interface Variant {
  sku: string;
  id: string;
  isbn: string;
  width?: number;
  height?: number;
  depth?: number;
  format: string;
  isDigital: boolean;
  isDefault: boolean;
}

interface ProductContributor {
  id: number;
  type: string;
}

interface Attribute {
  key: string;
  value: string;
}
```

## Installation

This gem is run as part of the [Huginn](https://github.com/huginn/huginn) project. If you haven't already, follow the [Getting Started](https://github.com/huginn/huginn#getting-started) instructions there.

Add this string to your Huginn's .env `ADDITIONAL_GEMS` configuration:

```ruby
huginn_acumen_product_agent
# when only using this agent gem it should look like this:
ADDITIONAL_GEMS=huginn_acumen_product_agent
```

And then execute:

    $ bundle

## Usage

TODO: Write usage instructions here

## Development

Running `rake` will clone and set up Huginn in `spec/huginn` to run the specs of the Gem in Huginn as if they would be build-in Agents. The desired Huginn repository and branch can be modified in the `Rakefile`:

```ruby
HuginnAgent.load_tasks(branch: '<your branch>', remote: 'https://github.com/<github user>/huginn.git')
```

Make sure to delete the `spec/huginn` directory and re-run `rake` after changing the `remote` to update the Huginn source code.

After the setup is done `rake spec` will only run the tests, without cloning the Huginn source again.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release` to create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Release

The standard release command for this project is:

```
npm version [<newversion> | major | minor | patch | premajor | preminor | prepatch | prerelease | from-git]
```

This command will:

1. Generate/update the Changelog
1. Bump the package version
1. Tag & pushing the commit


e.g.

```
npm version 1.2.17
npm ver

## Contributing

1. Fork it ( https://github.com/[my-github-username]/huginn_acumen_product_agent/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
