//import { Product, Person, ProductModel, Offer, Book, Review, QuantitativeValue } from "schema-dts";

//interface AcumenProduct extends Omit<Product & Book, '@type'> {
interface AcumenProduct {
  '@type': 'Product',

  identifier: string,  // some generated id for the product wrapper
  name: string;
  disambiguatingDescription?: string;  // subtitle

  description?: string;
  'abstract'?: string;
  keywords?: string;
  text?: string;

  publisher?: Array<{
    '@type': 'Organization',
    name: string;
  }>

  category?: Array<{
    '@type': 'Thing',
    identifier?: string;
    name?: string;
  }>

  additionalProperty: Array<{
    '@type': 'PropertyValue';
    propertyID: string;
    value: string;
  }>;

  model?: AcumenProductVariant[];

  // review?: Review[];

  additionalType?: 'Book'|string;
  // from http://schema.org/Book
  isbn?: string;
  datePublished?: string;
  numberOfPages?: number;
  author?: Array<{
    '@type': 'Person';
    identifier: string;
    name?: string;
  }>;
  contributor?: Array<{
    '@type': 'Person';
    identifier: string;
    name?: string;
  }>;

  /** special attributes, which are not user-facing */
  acumenAttributes: {
    [key: string]: string;
  };
}

//interface AcumenProductVariant extends Omit<ProductModel & Book, '@type'> {
interface AcumenProductVariant {
  '@type': 'ProductModel',
  identifier: string,  // acumen product id
  sku: string,
  gtin12?: string;  // aka upc

  offers?: Array<{
    '@type': 'Offer';
    price: string;
  }>;

  height?: QuantitativeValue;
  width?: QuantitativeValue;
  depth?: QuantitativeValue;
  weight?: QuantitativeValue;

  additionalType?: 'Book'|string;
  // from http://schema.org/Book
  bookFormat: "http://schema.org/Hardcover"|"http://schema.org/Paperback"|"http://schema.org/EBook",
  isbn?: string;
  numberOfPages?: number;

  // outside of schema.org definitions
  isDefaultVariant?: boolean;
  isTaxable?: boolean;

  /** special attributes, which are not user-facing */
  acumenAttributes?: {
    [key: string]: string;
  };
}

interface QuantitativeValue {
  '@type': 'QuantitativeValue';
  'value': string;
  'unitCode': string;
  'unitText': string;
}

const exampleProduct: AcumenProduct = {
  '@type': 'Product',
  "identifier": "STGMP-Product",
  "name": "Saint Gianna Molla",
  // "productID": "11117",
  // "sku": "STGMP",

  "additionalType": "Book",
  "datePublished": "2004-10-22T00:00:00",

  "model": [
    {
      '@type': 'ProductModel',
      "identifier": "11117",
      "sku": "STGMP",

      "additionalType": "Book",
      "bookFormat": "http://schema.org/Hardcover",
      "isbn": "9780898708875",
      "gtin12": "0898708877",  // aka upc
      "numberOfPages": 155,

      "offers": [{
        '@type': 'Offer',
        "price": "14.95",
      },{
        '@type': 'Offer',
        "price": "0",
      }],

      "weight": {
        '@type': 'QuantitativeValue',
        'value': "7.2",
        'unitCode': 'OZ',
        'unitText': 'oz',
      },

      "isDefaultVariant": true,
      "isTaxable": true,
    },
    {
      '@type': 'ProductModel',
      "identifier": "11116",
      "sku": "STGME",

      "additionalType": "Book",
      "bookFormat": "http://schema.org/EBook",
      "isbn": "9780898708875",

      "offers": [{
        '@type': 'Offer',
        "price": "14.95",
      }],

      "weight": {
        '@type': 'QuantitativeValue',
        "value": "0",
        'unitCode': 'OZ',
        'unitText': 'oz',
      },

      "isTaxable": true,
    },
  ],

  "description": "<p>This is the inspiring story of a canonized contemporary woman. Gianna Molla (1923-1962) risked her life in order to save her unborn child. Diagnosed with uterine tumors during her fourth pregnancy, she refused a hysterectomy that would have aborted the child, and opted for a riskier surgery in an attempt to save the baby. Herself a medical doctor, Molla did give birth to the child, but succumbed to an infection.<br /><br />An Italian woman who loved skiing, playing piano, attending concerts at the Milan Conservatory, Molla was a dedicated physician and devoted wife and mother who lived life to the fullest, yet generously risked death by cancer for the sake of her child.<br /><br />A unique story, co-authored by her own husband, with his deeply moving personal insights of the heroic witness, love, sacrifice and joy of his saintly wife. A woman for all times and walks of life, this moving account of the multi-faceted, selfless St. Gianna Molla, who made the ultimate sacrifice to save her unborn child, will be an inspiration to all readers. <em>Illustrated</em><br /><br />&#x201C;A woman of exceptional love, an outstanding wife and mother, Gianna Molla gave witness in her daily life to the demanding values of the Gospel.&#x201D;<br /><strong>&#151;Pope John Paul II</strong></p><p>&#160;</p>",

  "additionalProperty": [
    {
      '@type': 'PropertyValue',
      "propertyID": "info_boolean_1",
      "value": "0"
    },
    {
      '@type': 'PropertyValue',
      "propertyID": "meta_keywords",
      "value": "saints,women in the church,parenting,motherhood,family,marriage,st gianna molla,biography"
    },
    {
      '@type': 'PropertyValue',
      "propertyID": "extent_value",
      "value": "0"
    },
    {
      '@type': 'PropertyValue',
      "propertyID": "product_marketing_id",
      "value": "4078"
    }
  ],

  "contributor": [  // author?
    { '@type': 'Person', "identifier": "1048", "name": "" },
    { '@type': 'Person', "identifier": "1310", "name": "" },
  ],

  "category": [
    { '@type': 'Thing', "identifier": "1048", "name": "" },
    { '@type': 'Thing', "identifier": "1069", "name": "" },
    { '@type': 'Thing', "identifier": "1068", "name": "" },
    { '@type': 'Thing', "identifier": "1065", "name": "" },
    { '@type': 'Thing', "identifier": "1302", "name": "" },
  ]
};
