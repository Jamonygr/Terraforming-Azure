from decimal import Decimal
import json
import unittest
from tools.cost_estimate import ROOT, estimate, line_cost
from tools.refresh_cost_snapshot import matching_price


class CostTests(unittest.TestCase):
    def setUp(self):
        self.snapshot=json.loads((ROOT/'docs/cost-snapshot.json').read_text())
        self.inventory=json.loads((ROOT/'curriculum/costs.json').read_text())

    def test_inventory_covers_all_lessons_and_meters(self):
        self.assertEqual(list(self.inventory['labs']),[f'TFA-{i:03}' for i in range(1,41)])
        for entry in list(self.inventory['labs'].values())+list(self.inventory['stages'].values()):
            for key, qty in entry['resources'].items():
                self.assertIn(key,self.snapshot['meters'])
                self.assertGreater(qty,0)

    def test_monthly_prices_are_not_treated_as_hourly(self):
        self.assertEqual(line_cost(self.snapshot['meters']['dns_in'],1,730,self.snapshot),Decimal('180'))
        self.assertLess(line_cost(self.snapshot['meters']['dns_in'],1,4,self.snapshot),1)

    def test_dns_zones_bill_a_day_for_short_session(self):
        self.assertEqual(line_cost(self.snapshot['meters']['dns_zone'],1,4,self.snapshot),line_cost(self.snapshot['meters']['dns_zone'],1,24,self.snapshot))

    def test_stage_footprints_include_required_fixed_components(self):
        final=self.inventory['stages']['hybrid']['resources']
        for key, expected in {'vm':4,'ssd':4,'pip':6,'pe':2,'vpn':2,'nat':1,'dns_zone':3,'dns_in':1,'dns_out':1,'dns_rules':1,'waf_cu':10,'blob_gb':2}.items():
            self.assertEqual(final[key],expected)
        totals=[estimate(s['resources'],4,self.snapshot) for s in self.inventory['stages'].values()]
        self.assertEqual(totals,sorted(set(totals)))

    def test_invalid_quantities_hours_and_units_fail(self):
        for qty,hours in [(-1,4),(1,0),(1,float('inf')),(1,float('nan'))]:
            with self.assertRaises(ValueError):line_cost(self.snapshot['meters']['vm'],qty,hours,self.snapshot)
        for hours in [0,-1,float('inf'),float('nan')]:
            with self.assertRaises(ValueError):estimate({},hours,self.snapshot)
        with self.assertRaises(ValueError):line_cost({'retailPrice':1,'basis':'unknown'},1,4,self.snapshot)

    def test_price_selection_rejects_missing_ambiguous_or_different_tiers(self):
        meter=self.snapshot['meters']['log_gb']
        self.assertEqual(matching_price([meter],meter)['retailPrice'],2.99)
        for rows in [[],[{**meter,'tierMinimumUnits':0}], [meter,{**meter,'retailPrice':9}]]:
            with self.assertRaises(ValueError):matching_price(rows,meter)


if __name__=='__main__':unittest.main()
