"""Explicit public pricing refresh. No Azure login, subscription, or deployment API."""
import argparse
import calendar
from datetime import datetime, timezone
import json
from pathlib import Path
from urllib.parse import urlencode, urlparse
from urllib.request import urlopen

ROOT=Path(__file__).resolve().parents[1]


def matching_price(rows, selection):
    matches=[row for row in rows if all(row.get(key)==selection[key] for key in ('meterId','productName','meterName','armRegionName','unitOfMeasure','tierMinimumUnits'))]
    distinct={(row['retailPrice'],row['effectiveStartDate']) for row in matches}
    if len(distinct)!=1:
        raise ValueError(f"Missing or ambiguous exact selection for {selection['meterName']}; inspect product, region, tier and unit manually.")
    return matches[0]


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,required=True,help='Write a review candidate; compare with docs/cost-snapshot.json before replacement.')
    args=parser.parse_args()
    if args.output.resolve()==(ROOT/'docs/cost-snapshot.json').resolve():
        parser.error('Write a separate candidate first, then review its diff before replacing the authoritative snapshot.')
    snapshot=json.loads((ROOT/'docs/cost-snapshot.json').read_text(encoding='utf-8'))
    for key, selection in snapshot['meters'].items():
        query="meterId eq '"+selection['meterId']+"' and priceType eq 'Consumption'"
        url='https://prices.azure.com/api/retail/prices?'+urlencode({'currencyCode':snapshot['currency'],'$filter':query})
        rows=[]
        while url:
            if urlparse(url).scheme!='https' or urlparse(url).hostname!='prices.azure.com':
                raise ValueError('Unexpected pricing pagination host.')
            with urlopen(url,timeout=30) as response: page=json.load(response)
            rows.extend(page['Items']);url=page.get('NextPageLink')
        match=matching_price(rows,selection)
        selection.update(retailPrice=match['retailPrice'],effectiveStartDate=match['effectiveStartDate'])
        print(f"Selected {key}: {selection['retailPrice']} {snapshot['currency']} / {selection['unitOfMeasure']}")
    date=datetime.now(timezone.utc).date()
    snapshot.update(date=date.isoformat(),monthly_days=calendar.monthrange(date.year,date.month)[1])
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(snapshot,indent=2)+'\n',encoding='utf-8',newline='\n')
    print('Review quantities, SKU compatibility, units and assumptions before accepting this pricing candidate.')


if __name__=='__main__':main()
