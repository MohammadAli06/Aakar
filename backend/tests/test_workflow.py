import unittest
from app.services.workflow_service import apply, seed, readiness


class WorkflowTests(unittest.TestCase):
    def setUp(self):
        self.state = seed()

    def act(self, action, data, role='buyer', actor=None):
        self.state = apply(self.state, action, data, role, actor or ('buyer' if role == 'buyer' else 'admin' if role == 'admin' else 'ramesh'))

    def order(self, sample=False):
        self.act('inquiry', dict(product_id='basket', quantity=500, lead_days=30, location='Mumbai', sample_required=sample))
        self.rid = self.state['inquiries'][0]['id']
        self.act('capacity', dict(id=self.rid, status='confirmed', quantity=500, lead_days=30), 'artisan')
        self.act('quote', dict(id=self.rid, unit_price=300, quantity=500, lead_days=30, inspection_hours=24, milestones=[dict(trigger='advance', percent=30), dict(trigger='dispatch', percent=50), dict(trigger='delivery', percent=20)]), 'artisan')
        self.qid = self.state['inquiries'][0]['quotes'][-1]['id']
        if not sample:
            self.act('accept', dict(id=self.rid, quote_id=self.qid))
            return self.state['orders'][0]['id']

    def test_readiness_is_separate(self):
        p = self.state['products'][0]
        p.update(stock=0, customizable=False, external={})
        self.assertEqual(readiness(p), [])

    def test_availability_is_owned_boolean_and_preserves_catalog(self):
        before = self.state
        for role, actor in [('buyer', 'buyer'), ('artisan', 'sakhi')]:
            with self.assertRaises(ValueError):
                self.act('availability', dict(id='basket', available=False), role, actor)
            self.assertEqual(self.state, before)
        for value in [None, 'false', 0]:
            with self.assertRaises(ValueError):
                self.act('availability', dict(id='basket', available=value), 'artisan')
            self.assertEqual(self.state, before)
        product = dict(self.state['products'][0])
        self.act('availability', dict(id='basket', available=False, price=1), 'artisan')
        self.assertEqual(self.state['products'][0], {**product, 'available': False})
        with self.assertRaises(ValueError):
            self.act('inquiry', dict(product_id='basket', quantity=50, lead_days=30, location='Mumbai'))
        self.act('availability', dict(id='basket', available=True), 'artisan')
        self.act('inquiry', dict(product_id='basket', quantity=50, lead_days=30, location='Mumbai'))
        self.assertEqual(len(self.state['inquiries']), 1)

    def test_pausing_availability_preserves_orders(self):
        self.order()
        orders = self.state['orders']
        self.act('availability', dict(id='basket', available=False), 'artisan')
        self.assertEqual(self.state['orders'], orders)

    def test_sample_gate_and_duplicate_order(self):
        self.order(True)
        with self.assertRaises(ValueError):
            self.act('accept', dict(id=self.rid, quote_id=self.qid))
        self.act('sample', dict(id=self.rid, status='submitted', evidence='sample-photo'), 'artisan')
        self.act('sample', dict(id=self.rid, status='approved'))
        self.act('accept', dict(id=self.rid, quote_id=self.qid))
        self.act('accept', dict(id=self.rid, quote_id=self.qid))
        self.assertEqual(len(self.state['orders']), 1)

    def test_ownership_and_admin_permissions(self):
        oid = self.order()
        with self.assertRaises(ValueError):
            self.act('production', dict(id=oid, status='started'), 'artisan', 'sakhi')
        with self.assertRaises(ValueError):
            self.act('verify', dict(id='buyer', status='verified'))

    def test_complete_lifecycle(self):
        oid = self.order()
        with self.assertRaises(ValueError):
            self.act('production', dict(id=oid, status='started'), 'artisan')
        self.act('pay', dict(id=oid, milestone_id='m0'))
        for step in ('started', 'in_progress', 'ready'):
            self.act('production', dict(id=oid, status=step), 'artisan')
        self.act('pay', dict(id=oid, milestone_id='m1'))
        self.act('shipping', dict(id=oid, status='dispatched', method='Courier', tracking='DEMO', evidence='photo', route='Direct', checks=['protection', 'count', 'inner', 'outer']), 'artisan')
        self.act('delivery', dict(id=oid))
        with self.assertRaises(ValueError):
            self.act('inspection', dict(id=oid, quantity=470))
        self.act('inspection', dict(id=oid, quantity=500))
        with self.assertRaises(ValueError):
            self.act('complete', dict(id=oid))
        self.act('pay', dict(id=oid, milestone_id='m2'))
        self.act('complete', dict(id=oid))
        self.assertEqual(self.state['orders'][0]['status'], 'completed')

    def test_issue_blocks_and_requires_admin(self):
        oid = self.order()
        self.act('issue', dict(id=oid, category='Damage', description='Broken item', evidence='photo'))
        iid = self.state['issues'][0]['id']
        with self.assertRaises(ValueError):
            self.act('pay', dict(id=oid, milestone_id='m0'))
        with self.assertRaises(ValueError):
            self.act('resolve', dict(id=iid, status='resolved', note='Replacement agreed'))
        self.act('resolve', dict(id=iid, status='resolved', note='Replacement agreed'), 'admin')
        self.act('pay', dict(id=oid, milestone_id='m0'))


if __name__ == '__main__':
    unittest.main()
