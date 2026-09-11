"""Transactional demo workflow rules shared conceptually with CommerceEngine.

All callers receive a new snapshot. A rejected command never mutates stored state.
This workspace is explicitly demo-only; it is not a production payment system.
"""
import copy
import json
import math
import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path


def seed():
    return json.loads(Path(__file__).with_name('workflow_seed.json').read_text(encoding='utf-8'))


def num(value):
    try:
        result = float(value or 0)
        return result if math.isfinite(result) else 0
    except (TypeError, ValueError):
        return 0


def need(ok, message):
    if not ok:
        raise ValueError(message)


def cost_floor(p):
    return sum(num(p.get(k)) for k in ('material_cost', 'labour_cost', 'overhead'))


def readiness(p):
    gaps = [k for k in ('title', 'description', 'image', 'location', 'category') if not str(p.get(k, '')).strip()]
    gaps += [k for k in ('price', 'moq', 'lead_days') if num(p.get(k)) <= 0]
    gaps += [k for k in ('stock', 'capacity') if k not in p or num(p[k]) < 0]
    if num(p.get('stock')) + num(p.get('capacity')) <= 0:
        gaps.append('stock or production capacity')
    gaps += [k for k in ('available', 'customizable') if not isinstance(p.get(k), bool)]
    if p.get('approved') is not True:
        gaps.append('artisan approval')
    if num(p.get('price')) < cost_floor(p):
        gaps.append('price below cost floor')
    return gaps


def apply(original, action, data, role, actor):
    state = copy.deepcopy(original)
    now = datetime.now(timezone.utc).isoformat()

    def ident(prefix):
        return f'{prefix}-{uuid.uuid4().hex[:16]}'

    def find(table, key):
        result = next((r for r in state[table] if r['id'] == key), None)
        need(result is not None, 'Record not found')
        return result

    def as_role(required):
        need(role == required, f'{required} role required')

    def owned(record):
        need(role == 'admin' or record.get(f'{role}_id') == actor, 'Record belongs to another participant')
        return record

    def inquiry():
        return owned(find('inquiries', data.get('id')))

    def order():
        return owned(find('orders', data.get('id')))

    def event(record, title):
        record.setdefault('events', []).append(dict(title=title, time=now, actor=actor, role=role))
        if 'production' in record:
            for target_role in ('buyer', 'artisan'):
                if role != target_role:
                    notify(title, record[f'{target_role}_id'], target_role, f"order/{record['id']}")

    def notify(title, target, target_role, link=None):
        state['notifications'].insert(0, dict(id=ident('notice'), title=title, actor_id=target, role=target_role, link=link, read=False, time=now))

    def unblocked(o):
        need(not any(i['order_id'] == o['id'] and i['status'] != 'resolved' for i in state['issues']), 'Resolve the open issue first')

    def paid(o, trigger):
        return all(m['status'] == 'confirmed' for m in o['milestones'] if m['trigger'] == trigger)

    if action == 'profile':
        p = find('profiles', actor)
        need(p['role'] == role, 'Profile role mismatch')
        for k in ('name', 'email', 'phone', 'type', 'industry', 'location', 'website', 'document', 'contact_verified', 'terms', 'craft', 'experience', 'story'):
            if k in data:
                p[k] = data[k]
        need(p.get('name', '').strip() and p.get('location', '').strip(), 'Name and location required')
        if data.get('submit'):
            need(p.get('document') and p.get('terms') is True and p.get('contact_verified') is True, 'Evidence, contact confirmation and consent required')
            p['verification'] = 'pending'
    elif action == 'product':
        as_role('artisan')
        p = owned(find('products', data['id'])) if data.get('id') else dict(id=ident('product'), artisan_id=actor, status='draft', external={})
        for k in ('title', 'title_hi', 'description_hi', 'description', 'category', 'craft', 'material', 'colour', 'dimensions', 'usage', 'story', 'price', 'material_cost', 'labour_cost', 'labour_hours', 'hourly_rate', 'complexity', 'overhead', 'moq', 'stock', 'capacity', 'lead_days', 'available', 'customizable', 'location', 'image', 'original_image', 'fragile', 'can_pack', 'transcript', 'approved'):
            if k in data:
                p[k] = data[k]
        need(all(num(p.get(k)) >= 0 for k in ('price', 'material_cost', 'labour_cost', 'overhead', 'stock', 'capacity')), 'Costs and capacity cannot be negative')
        p['status'] = 'needs_update' if p['status'] == 'published' else 'draft' if readiness(p) else 'ready'
        if not data.get('id'):
            state['products'].append(p)
    elif action == 'publish':
        as_role('artisan')
        p = owned(find('products', data.get('id')))
        need(not readiness(p), 'Complete readiness: ' + ', '.join(readiness(p)))
        need(p.get('moderation') != 'flagged', 'Resolve moderation before publishing')
        p['status'] = 'published'
    elif action == 'channel':
        as_role('artisan')
        p = owned(find('products', data.get('id')))
        need(data.get('channel') in ('gem', 'ondc', 'state_board'), 'Unknown channel')
        p.setdefault('external', {})[data['channel']] = dict(fields=data.get('fields', {}), status='prepared_demo', time=now)
    elif action == 'requirement':
        as_role('buyer')
        need(data.get('confirmed') is True and data.get('product') and data.get('location') and num(data.get('quantity')) > 0 and num(data.get('lead_days')) > 0, 'Confirm product, quantity, deadline and destination')
        state['requirements'].insert(0, {**data, 'id': ident('req'), 'buyer_id': actor, 'status': 'open', 'time': now})
    elif action == 'inquiry':
        as_role('buyer')
        p = find('products', data.get('product_id'))
        need(p['status'] == 'published', 'Product is not published')
        need(num(data.get('quantity')) >= num(p['moq']) and num(data.get('lead_days')) > 0 and data.get('location'), 'Quantity must meet MOQ; deadline and location required')
        r = {**data, 'id': ident('rfq'), 'buyer_id': actor, 'artisan_id': p['artisan_id'], 'product_title': p['title'], 'status': 'sent', 'capacity_status': 'pending', 'sample_status': 'requested' if data.get('sample_required') else 'not_required', 'messages': [], 'quotes': [], 'events': [], 'time': now}
        event(r, 'Inquiry sent')
        state['inquiries'].insert(0, r)
        notify('New inquiry · ' + p['title'], p['artisan_id'], 'artisan', 'inquiry/' + r['id'])
    elif action == 'message':
        r = inquiry()
        need(str(data.get('text', '')).strip(), 'Enter a message')
        r['messages'].append(dict(id=ident('message'), text=data['text'], translation=data.get('translation', ''), role=role, actor=actor, time=now, attachment=data.get('attachment', ''), provenance=data.get('provenance', 'original')))
        other = 'artisan' if role == 'buyer' else 'buyer'
        notify('New message · ' + r['product_title'], r[other + '_id'], other, 'inquiry/' + r['id'])
    elif action == 'capacity':
        as_role('artisan')
        r = inquiry()
        need(data.get('status') in ('confirmed', 'partial', 'declined'), 'Invalid capacity response')
        need(data['status'] == 'declined' or num(data.get('quantity')) > 0 and num(data.get('lead_days')) > 0, 'Confirm quantity and lead time')
        need(data['status'] != 'confirmed' or num(data.get('quantity')) >= num(r['quantity']), 'Use Partial for smaller quantity')
        r.update(capacity_status=data['status'], confirmed_quantity=data.get('quantity'), offered_lead_days=data.get('lead_days'))
        event(r, 'Capacity ' + data['status'])
    elif action == 'sample':
        r = inquiry()
        need(r.get('sample_required'), 'No sample requested')
        status = data.get('status')
        if role == 'artisan':
            need(status == 'submitted' and r['sample_status'] in ('requested', 'changes_requested', 'rejected') and data.get('evidence'), 'Submit requested sample with evidence')
            r.update(sample_evidence=data['evidence'], sample_terms=data.get('terms', ''))
        else:
            as_role('buyer')
            need(r['sample_status'] == 'submitted' and status in ('approved', 'changes_requested', 'rejected'), 'Review submitted sample')
        r.update(sample_status=status, sample_note=data.get('note', ''))
        if status == 'approved':
            basis = r['quotes'][-1] if r['quotes'] else r
            r['sample_basis'] = {k: basis.get(k, '') for k in ('customization', 'specifications')}
        event(r, 'Sample ' + status)
    elif action == 'quote':
        r = inquiry()
        need(r['status'] != 'ordered' and r['capacity_status'] in ('confirmed', 'partial'), 'Confirm capacity before quotation')
        p = find('products', r['product_id'])
        need(num(p['moq']) <= num(data.get('quantity')) <= num(r.get('confirmed_quantity')), 'Quantity must satisfy MOQ and confirmed capacity')
        need(num(data.get('unit_price')) >= cost_floor(p), 'Price below cost floor')
        need(num(data.get('lead_days')) > 0 and num(data.get('inspection_hours')) > 0, 'Lead time and inspection window required')
        milestones = data.get('milestones', [])
        need(milestones and abs(sum(num(m.get('percent')) for m in milestones) - 100) < .01, 'Milestones must total 100%')
        need(all(num(m.get('percent')) > 0 and m.get('trigger') in ('advance', 'checkpoint', 'dispatch', 'delivery') for m in milestones), 'Invalid milestone')
        need(any(m['trigger'] == 'advance' for m in milestones), 'Agree an advance')
        need(not any(m['trigger'] == 'checkpoint' for m in milestones) or data.get('checkpoint_required') is True, 'QC milestone requires checkpoint')
        charges = ('packaging_cost', 'delivery_cost', 'storage_cost', 'demo_cost')
        need(all(num(data.get(k)) >= 0 for k in charges), 'Charges cannot be negative')
        total = num(data['unit_price']) * num(data['quantity']) + sum(num(data.get(k)) for k in charges)
        q = {**data, 'id': ident('quote'), 'version': len(r['quotes']) + 1, 'author': role, 'time': now, 'total': total, 'currency': 'INR', 'status': 'proposed'}
        if r.get('sample_required') and r['sample_status'] == 'approved' and 'sample_basis' in r:
            if any(str(data.get(k) or '') != str(r['sample_basis'].get(k) or '') for k in ('customization', 'specifications')):
                r['sample_status'] = 'requested'
                event(r, 'Specifications changed; sample approval required again')
        r['quotes'].append(q)
        r['status'] = 'negotiating'
        event(r, f'Quote v{q["version"]} proposed')
        other = 'artisan' if role == 'buyer' else 'buyer'
        notify('New quote · ' + r['product_title'], r[other + '_id'], other, 'inquiry/' + r['id'])
    elif action in ('accept', 'reject_quote'):
        r = inquiry()
        need(r['quotes'], 'No quote')
        q = r['quotes'][-1]
        if action == 'reject_quote':
            need(r['status'] != 'ordered' and q['author'] != role, 'Cannot reject this quote')
            q['status'] = 'rejected'
            event(r, 'Quote rejected')
        else:
            need(q['id'] == data.get('quote_id'), 'Quote changed; refresh and review')
            if r['status'] == 'ordered':
                return state
            need(q['author'] != role and q['status'] == 'proposed', 'The other participant must accept an open quote')
            need(not r.get('sample_required') or r['sample_status'] == 'approved', 'Approve sample before bulk order')
            p = find('products', r['product_id'])
            committed = sum(num(o['quantity']) for o in state['orders'] if o['product_id'] == p['id'] and o['status'] != 'completed')
            need(num(p['stock']) + num(p['capacity']) * num(q['lead_days']) / 30 - committed >= num(q['quantity']), 'Capacity changed; revise the quote')
            o = {**copy.deepcopy(q), 'id': ident('order'), 'inquiry_id': r['id'], 'product_id': p['id'], 'product_title': p['title'], 'buyer_id': r['buyer_id'], 'artisan_id': r['artisan_id'], 'quote_id': q['id'], 'status': 'confirmed', 'production': 'not_started', 'shipment': 'not_dispatched', 'inspection': 'pending', 'checkpoint': 'not_submitted', 'events': [], 'packaging_checks': [], 'time': now, 'payment_mode': 'demo'}
            o['milestones'] = [{**m, 'id': f'm{i}', 'amount': round(num(q['total']) * num(m['percent']) / 100, 2), 'status': 'pending'} for i, m in enumerate(q['milestones'])]
            event(o, f'Order confirmed · quote v{q["version"]}')
            state['orders'].insert(0, o)
            r.update(status='ordered', order_id=o['id'])
            q['status'] = 'accepted'
            for target_role in ('buyer', 'artisan'):
                notify('Order confirmed · ' + p['title'], r[target_role + '_id'], target_role, 'order/' + o['id'])
    elif action == 'pay':
        as_role('buyer')
        o = order()
        unblocked(o)
        m = next((m for m in o['milestones'] if m['id'] == data.get('milestone_id')), None)
        need(m is not None, 'Unknown milestone')
        need(m['trigger'] != 'checkpoint' or o['checkpoint'] == 'approved', 'Approve progress first')
        need(m['trigger'] != 'dispatch' or o['production'] in ('ready', 'dispatched'), 'Production must be ready')
        need(m['trigger'] != 'delivery' or o['inspection'] == 'accepted', 'Accept inspection before final settlement')
        m.update(status='confirmed', reference=data.get('reference', 'Simulated payment'), confirmed_at=now, mode='demo')
        event(o, m['trigger'] + ' payment recorded · simulation')
    elif action == 'production':
        as_role('artisan')
        o = order()
        unblocked(o)
        steps = dict(not_started='started', started='in_progress', in_progress='ready')
        need(steps.get(o['production']) == data.get('status'), 'Follow production steps in order')
        need(paid(o, 'advance'), 'Confirm advance before production')
        if data['status'] == 'ready':
            need(not o.get('checkpoint_required') or o['checkpoint'] == 'approved', 'Complete progress review')
            need(paid(o, 'checkpoint'), 'Confirm QC milestone')
        o['production'] = data['status']
        o['status'] = 'ready' if data['status'] == 'ready' else 'in_production'
        event(o, 'Production ' + data['status'])
    elif action == 'checkpoint':
        o = order()
        unblocked(o)
        need(o.get('checkpoint_required') and o['production'] in ('started', 'in_progress'), 'No active production checkpoint')
        if role == 'artisan':
            need(0 < num(data.get('quantity')) <= num(o['quantity']) and data.get('evidence'), 'Provide completed quantity and evidence')
            o.update(checkpoint='submitted', checkpoint_quantity=data['quantity'], checkpoint_evidence=data['evidence'])
        else:
            need(role in ('buyer', 'admin') and o['checkpoint'] == 'submitted' and data.get('status') in ('approved', 'changes_requested'), 'Review submitted progress')
            o['checkpoint'] = data['status']
        event(o, 'Progress checkpoint ' + o['checkpoint'])
    elif action == 'shipping':
        as_role('artisan')
        o = order()
        unblocked(o)
        if data.get('status') == 'dispatched':
            need(o['production'] == 'ready' and paid(o, 'dispatch'), 'Ready state and dispatch milestone required')
            need(data.get('method') and data.get('tracking') and data.get('evidence'), 'Method, tracking and evidence required')
            need(set(data.get('checks', [])) >= {'protection', 'count', 'inner', 'outer'} and data.get('route') in ('Direct', 'Via hub'), 'Complete packaging and feasible routing')
            need(data['route'] != 'Via hub' or data.get('hub_available') is True and data.get('hub_details'), 'Confirm hub and handoff details')
            product = find('products', o['product_id'])
            wants_hub = product.get('can_pack') is not True or num(o['quantity']) > 500 or data.get('storage_needed') is True
            expected_route = 'Needs review' if wants_hub and data.get('hub_available') is None else 'Via hub' if wants_hub and data.get('hub_available') is True else 'Direct' if product.get('can_pack') is True and data.get('storage_needed') is not True else 'Needs review'
            need(data['route'] == expected_route, 'Confirm a route supported by packaging, storage and hub availability')
            o.update(production='dispatched', shipment='dispatched', status='dispatched', shipping=copy.deepcopy(data))
        else:
            need(data.get('status') == 'in_transit' and o['shipment'] == 'dispatched', 'Dispatch before transit')
            o.update(shipment='in_transit', status='in_transit')
        event(o, 'Shipment ' + o['shipment'] + ' · manual tracking')
    elif action == 'delivery':
        as_role('buyer')
        o = order()
        need(o['shipment'] in ('dispatched', 'in_transit'), 'Dispatch before receipt')
        o.update(shipment='delivered', status='delivered', delivered_at=now, inspection_deadline=(datetime.now(timezone.utc) + timedelta(hours=num(o['inspection_hours']))).isoformat())
        event(o, 'Buyer confirmed receipt; inspection pending')
    elif action == 'inspection':
        as_role('buyer')
        o = order()
        unblocked(o)
        need(o['shipment'] == 'delivered', 'Confirm receipt first')
        need(num(data.get('quantity')) == num(o['quantity']), 'Quantity mismatch: flag an issue')
        o.update(inspection='accepted', inspection_note=data.get('note', ''))
        event(o, 'Buyer accepted inspection')
    elif action == 'complete':
        as_role('buyer')
        o = order()
        unblocked(o)
        need(o['shipment'] == 'delivered' and o['inspection'] == 'accepted' and all(m['status'] == 'confirmed' for m in o['milestones']), 'Delivery, inspection and settlement required')
        if o['status'] == 'completed':
            return state
        o['status'] = 'completed'
        p = find('products', o['product_id'])
        p['stock'] = max(0, num(p['stock']) - num(o['quantity']))
        event(o, 'Order completed')
    elif action == 'issue':
        o = order()
        need(o['status'] != 'completed' and str(data.get('description', '')).strip(), 'Describe an issue on an open order')
        state['issues'].insert(0, {**data, 'id': ident('issue'), 'order_id': o['id'], 'buyer_id': o['buyer_id'], 'artisan_id': o['artisan_id'], 'reporter': actor, 'status': 'open', 'time': now})
        event(o, 'Issue flagged: ' + data.get('category', 'Other'))
    elif action == 'resolve':
        as_role('admin')
        issue = find('issues', data.get('id'))
        need(str(data.get('note', '')).strip() and data.get('status') in ('under_review', 'resolved'), 'Record the manual review outcome')
        issue.update(status=data['status'], resolution=data['note'], reviewed_at=now)
        event(find('orders', issue['order_id']), 'Admin issue review: ' + data['status'])
    elif action == 'verify':
        as_role('admin')
        p = find('profiles', data.get('id'))
        need(data.get('status') in ('verified', 'rejected', 'correction_requested'), 'Invalid decision')
        p.update(verification=data['status'], verification_note=data.get('note', ''))
        notify('Verification ' + data['status'], p['id'], p['role'])
    elif action == 'moderate':
        as_role('admin')
        p = find('products', data.get('id'))
        need(data.get('status') in ('flagged', 'clear'), 'Invalid moderation decision')
        p.update(moderation=data['status'], moderation_note=data.get('note', ''))
        if data['status'] == 'flagged':
            p['status'] = 'needs_update'
    elif action == 'save_supplier':
        as_role('buyer')
        find('profiles', data.get('artisan_id'))
        key = f'{actor}:{data["artisan_id"]}'
        state['saved'].remove(key) if key in state['saved'] else state['saved'].append(key)
    elif action == 'representation':
        o = order()
        need(data.get('purpose') and data.get('location') and data.get('date'), 'Purpose, location and date required')
        if data.get('status') == 'confirmed':
            need(o.get('representation') and o['representation']['author'] != role, 'Other participant must confirm')
        o['representation'] = {**data, 'author': role, 'mode': 'demo coordination'}
        event(o, 'On-site demo ' + data.get('status', 'proposed'))
    elif action == 'read_notifications':
        for n in state['notifications']:
            if n['actor_id'] == actor and n['role'] == role:
                n['read'] = True
    else:
        raise ValueError('Unknown workflow action')
    state['version'] = original['version'] + 1
    return state
