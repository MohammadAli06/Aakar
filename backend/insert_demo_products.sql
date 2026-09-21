-- Insert 4 products directly into craftconnect database
-- Artisan: Ramesh Kumar (ceeac845-ee51-4c05-991a-fe208e63d4de)

BEGIN;

-- 1. Bamboo Basket (Product ID: p1000000-0000-0000-0000-000000000001)
INSERT INTO products (id, artisan_id, category, status, created_at, updated_at)
VALUES (
    'a1000000-0000-0000-0000-000000000001',
    'ceeac845-ee51-4c05-991a-fe208e63d4de',
    'weaving',
    'published',
    NOW(),
    NOW()
);

INSERT INTO product_listings (
    id, product_id, title_en, title_hi, desc_en, desc_hi, attributes,
    confidence_scores, tags, craft_terms, voice_transcript, verification_status, created_at, updated_at
) VALUES (
    'b1000000-0000-0000-0000-000000000001',
    'a1000000-0000-0000-0000-000000000001',
    'Handwoven Bamboo Fruit Basket',
    'हस्तनिर्मित बाँस की टोकरी',
    'Handcrafted multi-utility round bamboo basket woven from seasoned natural river cane. Sturdy base with decorative rim, ideal for fruits, bread, and tabletop decor.',
    'प्राकृतिक नदी के पके बाँस से बुनी गई बहुउपयोगी गोल टोकरी। फल, रोटी और मेज की सजावट के लिए मजबूत आधार और सुंदर किनारी।',
    '{
        "title": "Handwoven Bamboo Fruit Basket",
        "title_hi": "हस्तनिर्मित बाँस की टोकरी",
        "description": "Handcrafted multi-utility round bamboo basket woven from seasoned natural river cane. Sturdy base with decorative rim, ideal for fruits, bread, and tabletop decor.",
        "description_hi": "प्राकृतिक नदी के पके बाँस से बुनी गई बहुउपयोगी गोल टोकरी। फल, रोटी और मेज की सजावट के लिए मजबूत आधार और सुंदर किनारी।",
        "category": "Baskets",
        "ui_category": "Baskets",
        "craft": "Bamboo Weaving",
        "material": "Bamboo",
        "colour": "Natural Pale Yellow",
        "dimensions": "30 x 30 x 12 cm",
        "usage": "Fruit Basket, Tabletop Organizer, Gifting",
        "story": "Woven using age-old North-Eastern bamboo splits technique, sun-dried without toxic varnishes.",
        "location": "Raigad, Maharashtra",
        "moq": 20.0,
        "stock": 250.0,
        "capacity": 500.0,
        "lead_days": 7.0,
        "available": true,
        "customizable": true,
        "fragile": false,
        "can_pack": true,
        "prepared": "plainBackground",
        "photo_provider": "openai",
        "photo_reviewed": true,
        "catalog_plain_background": true,
        "image": "/api/v1/products/images/demo_bamboo_basket.jpg",
        "original_image": "/api/v1/products/images/demo_bamboo_basket.jpg"
    }'::jsonb,
    '{}'::jsonb,
    '["bamboo", "handwoven", "eco-friendly", "basket"]'::jsonb,
    '["cane", "split bamboo"]'::jsonb,
    'यह हाथ से बुनी बाँस की टोकरी है',
    'approved',
    NOW(),
    NOW()
);

INSERT INTO price_recommendations (
    id, product_id, material_cost, labour_cost, overhead, craftsmanship_score,
    comparable_ids, recommended_min, recommended_max, final_price,
    explanation_text_en, explanation_text_hi, verification_status, created_at
) VALUES (
    'c1000000-0000-0000-0000-000000000001',
    'a1000000-0000-0000-0000-000000000001',
    110.0, 140.0, 30.0, 0.65,
    '["comp_bamboo_1"]'::jsonb,
    380.0, 480.0, 420.0,
    '₹380–₹480 recommended because your total cost is ₹280 (materials ₹110 + labour ₹140 + overhead ₹30). Similar handmade bamboo baskets sell for ₹450–₹600. Your craftsmanship score of 65% earns a premium margin.',
    '₹380–₹480 की सिफारिश की जाती है क्योंकि आपकी कुल लागत ₹280 है (सामग्री ₹110 + मजदूरी ₹140 + अन्य ₹30)। इसी तरह की हस्तनिर्मित बाँस की टोकरियाँ ₹450–₹600 में बिकती हैं।',
    'approved',
    NOW()
);

INSERT INTO product_images (
    id, product_id, original_url, enhanced_url, verification_status, created_at
) VALUES (
    'd1000000-0000-0000-0000-000000000001',
    'a1000000-0000-0000-0000-000000000001',
    '/api/v1/products/images/demo_bamboo_basket.jpg',
    '/api/v1/products/images/demo_bamboo_basket.jpg',
    'approved',
    NOW()
);


-- 2. Hand Embroidered Cloth (Product ID: a1000000-0000-0000-0000-000000000002)
INSERT INTO products (id, artisan_id, category, status, created_at, updated_at)
VALUES (
    'a1000000-0000-0000-0000-000000000002',
    'ceeac845-ee51-4c05-991a-fe208e63d4de',
    'embroidery',
    'published',
    NOW(),
    NOW()
);

INSERT INTO product_listings (
    id, product_id, title_en, title_hi, desc_en, desc_hi, attributes,
    confidence_scores, tags, craft_terms, voice_transcript, verification_status, created_at, updated_at
) VALUES (
    'b1000000-0000-0000-0000-000000000002',
    'a1000000-0000-0000-0000-000000000002',
    'Hand Embroidered Floral Cotton Fabric',
    'हाथ से कढ़ाई किया हुआ सूती कपड़ा',
    'Pure handloom cotton running fabric intricately embroidered with traditional needlepoint floral motifs and mirror-work borders. Soft, breathable, and pre-washed.',
    'पारंपरिक सुई-धागे की फूलों की कढ़ाई और शीशे के काम से सुसज्जित शुद्ध हथकरघा सूती कपड़ा। मुलायम, आरामदायक और धोने योग्य।',
    '{
        "title": "Hand Embroidered Floral Cotton Fabric",
        "title_hi": "हाथ से कढ़ाई किया हुआ सूती कपड़ा",
        "description": "Pure handloom cotton running fabric intricately embroidered with traditional needlepoint floral motifs and mirror-work borders. Soft, breathable, and pre-washed.",
        "description_hi": "पारंपरिक सुई-धागे की फूलों की कढ़ाई और शीशे के काम से सुसज्जित शुद्ध हथकरघा सूती कपड़ा। मुलायम, आरामदायक और धोने योग्य।",
        "category": "Textiles",
        "ui_category": "Textiles",
        "craft": "Hand Embroidery",
        "material": "Cotton",
        "colour": "Indigo Blue with Multi-color threads",
        "dimensions": "100 x 110 cm (per meter)",
        "usage": "Apparel, Cushion Covers, Dupattas, Table Runner",
        "story": "Each flower motif is stitched by rural women artisans using authentic Kashida and Kantha stitch techniques.",
        "location": "Raigad, Maharashtra",
        "moq": 15.0,
        "stock": 180.0,
        "capacity": 300.0,
        "lead_days": 10.0,
        "available": true,
        "customizable": true,
        "fragile": false,
        "can_pack": true,
        "prepared": "plainBackground",
        "photo_provider": "openai",
        "photo_reviewed": true,
        "catalog_plain_background": true,
        "image": "/api/v1/products/images/demo_embroidered_cloth.jpg",
        "original_image": "/api/v1/products/images/demo_embroidered_cloth.jpg"
    }'::jsonb,
    '{}'::jsonb,
    '["cotton", "hand embroidery", "kantha", "needlework"]'::jsonb,
    '["kantha", "kashida"]'::jsonb,
    'शुद्ध सूती पर हाथ की बारीक कढ़ाई',
    'approved',
    NOW(),
    NOW()
);

INSERT INTO price_recommendations (
    id, product_id, material_cost, labour_cost, overhead, craftsmanship_score,
    comparable_ids, recommended_min, recommended_max, final_price,
    explanation_text_en, explanation_text_hi, verification_status, created_at
) VALUES (
    'c1000000-0000-0000-0000-000000000002',
    'a1000000-0000-0000-0000-000000000002',
    220.0, 300.0, 40.0, 0.80,
    '["comp_textile_1"]'::jsonb,
    760.0, 950.0, 850.0,
    '₹760–₹950 recommended because your total cost is ₹560 (materials ₹220 + labour ₹300 + overhead ₹40). High detail embroidery warrants an 80% craftsmanship rating with strong B2B margin.',
    '₹760–₹950 की सिफारिश की जाती है क्योंकि आपकी कुल लागत ₹560 है। बारीक कढ़ाई के लिए 80% शिल्पकारी स्कोर दिया गया है।',
    'approved',
    NOW()
);

INSERT INTO product_images (
    id, product_id, original_url, enhanced_url, verification_status, created_at
) VALUES (
    'd1000000-0000-0000-0000-000000000002',
    'a1000000-0000-0000-0000-000000000002',
    '/api/v1/products/images/demo_embroidered_cloth.jpg',
    '/api/v1/products/images/demo_embroidered_cloth.jpg',
    'approved',
    NOW()
);


-- 3. White Ceramic Mug (Product ID: a1000000-0000-0000-0000-000000000003)
INSERT INTO products (id, artisan_id, category, status, created_at, updated_at)
VALUES (
    'a1000000-0000-0000-0000-000000000003',
    'ceeac845-ee51-4c05-991a-fe208e63d4de',
    'pottery',
    'published',
    NOW(),
    NOW()
);

INSERT INTO product_listings (
    id, product_id, title_en, title_hi, desc_en, desc_hi, attributes,
    confidence_scores, tags, craft_terms, voice_transcript, verification_status, created_at, updated_at
) VALUES (
    'b1000000-0000-0000-0000-000000000003',
    'a1000000-0000-0000-0000-000000000003',
    'Artisanal White Ceramic Coffee Mug',
    'हस्तनिर्मित सफेद सिरेमिक मग',
    'Studio pottery stoneware ceramic mug wheel-thrown and high-fired at 1220°C. Finished with a food-safe matte white glaze and an ergonomic comfort handle.',
    'कुम्हार के चाक पर बना और 1220°C पर पकाया गया स्टोनवेयर सिरेमिक मग। सुरक्षित मैट सफेद ग्लेज़ और पकड़ने में आसान हैंडल।',
    '{
        "title": "Artisanal White Ceramic Coffee Mug",
        "title_hi": "हस्तनिर्मित सफेद सिरेमिक मग",
        "description": "Studio pottery stoneware ceramic mug wheel-thrown and high-fired at 1220°C. Finished with a food-safe matte white glaze and an ergonomic comfort handle.",
        "description_hi": "कुम्हार के चाक पर बना और 1220°C पर पकाया गया स्टोनवेयर सिरेमिक मग। सुरक्षित मैट सफेद ग्लेज़ और पकड़ने में आसान हैंडल।",
        "category": "Pottery",
        "ui_category": "Pottery",
        "craft": "Studio Pottery / Wheel Throwing",
        "material": "Ceramic Stoneware",
        "colour": "Matte Off-White",
        "dimensions": "8.5 cm dia x 10 cm height (320 ml)",
        "usage": "Tea, Coffee, Daily Beverage, Cafe Supplies",
        "story": "Hand-thrown individually on potter wheel, making every piece slightly unique in form and character.",
        "location": "Raigad, Maharashtra",
        "moq": 30.0,
        "stock": 400.0,
        "capacity": 800.0,
        "lead_days": 8.0,
        "available": true,
        "customizable": true,
        "fragile": true,
        "can_pack": true,
        "prepared": "plainBackground",
        "photo_provider": "openai",
        "photo_reviewed": true,
        "catalog_plain_background": true,
        "image": "/api/v1/products/images/demo_ceramic_mug.jpg",
        "original_image": "/api/v1/products/images/demo_ceramic_mug.jpg"
    }'::jsonb,
    '{}'::jsonb,
    '["ceramic", "pottery", "mug", "stoneware", "coffee"]'::jsonb,
    '["wheel thrown", "stoneware", "matte glaze"]'::jsonb,
    'चाक पर बना शुद्ध सफेद सिरेमिक मग',
    'approved',
    NOW(),
    NOW()
);

INSERT INTO price_recommendations (
    id, product_id, material_cost, labour_cost, overhead, craftsmanship_score,
    comparable_ids, recommended_min, recommended_max, final_price,
    explanation_text_en, explanation_text_hi, verification_status, created_at
) VALUES (
    'c1000000-0000-0000-0000-000000000003',
    'a1000000-0000-0000-0000-000000000003',
    80.0, 90.0, 30.0, 0.55,
    '["comp_ceramic_1"]'::jsonb,
    270.0, 360.0, 320.0,
    '₹270–₹360 recommended because your total cost is ₹200 (clay and glaze ₹80 + kiln & labour ₹90 + overhead ₹30). Competitive cafe-tier handmade ceramic pricing.',
    '₹270–₹360 की सिफारिश की जाती है क्योंकि आपकी कुल लागत ₹200 है। कैफे और उपहारों के लिए उचित कीमत।',
    'approved',
    NOW()
);

INSERT INTO product_images (
    id, product_id, original_url, enhanced_url, verification_status, created_at
) VALUES (
    'd1000000-0000-0000-0000-000000000003',
    'a1000000-0000-0000-0000-000000000003',
    '/api/v1/products/images/demo_ceramic_mug.jpg',
    '/api/v1/products/images/demo_ceramic_mug.jpg',
    'approved',
    NOW()
);


-- 4. Brass Diya (Product ID: a1000000-0000-0000-0000-000000000004)
INSERT INTO products (id, artisan_id, category, status, created_at, updated_at)
VALUES (
    'a1000000-0000-0000-0000-000000000004',
    'ceeac845-ee51-4c05-991a-fe208e63d4de',
    'metalcraft',
    'published',
    NOW(),
    NOW()
);

INSERT INTO product_listings (
    id, product_id, title_en, title_hi, desc_en, desc_hi, attributes,
    confidence_scores, tags, craft_terms, voice_transcript, verification_status, created_at, updated_at
) VALUES (
    'b1000000-0000-0000-0000-000000000004',
    'a1000000-0000-0000-0000-000000000004',
    'Traditional Hand-Cast Brass Diya Oil Lamp',
    'पारंपरिक पीतल का हस्तनिर्मित दीया',
    'Heavy solid brass oil lamp hand-cast using the lost-wax (Dhokra) sand casting method. Carved with decorative petal engravings and hand-polished to a golden sheen.',
    'ढलाई विधि से बना ठोस पीतल का तेल दीया। पंखुड़ियों की सुंदर नक्काशी और हाथों से सुनहरी पॉलिश किया हुआ।',
    '{
        "title": "Traditional Hand-Cast Brass Diya Oil Lamp",
        "title_hi": "पारंपरिक पीतल का हस्तनिर्मित दीया",
        "description": "Heavy solid brass oil lamp hand-cast using the lost-wax (Dhokra) sand casting method. Carved with decorative petal engravings and hand-polished to a golden sheen.",
        "description_hi": "ढलाई विधि से बना ठोस पीतल का तेल दीया। पंखुड़ियों की सुंदर नक्काशी और हाथों से सुनहरी पॉलिश किया हुआ।",
        "category": "Metalcraft",
        "ui_category": "Metalcraft",
        "craft": "Brass Metal Casting",
        "material": "Brass",
        "colour": "Antique Golden Yellow",
        "dimensions": "12 x 12 x 6 cm (approx 380 grams)",
        "usage": "Pooja, Festive Lighting, Temple Decor, Diwali Gifting",
        "story": "Cast by traditional metal smiths using pure brass metal scrap melted in crucible furnaces and hand-finished.",
        "location": "Raigad, Maharashtra",
        "moq": 25.0,
        "stock": 300.0,
        "capacity": 600.0,
        "lead_days": 12.0,
        "available": true,
        "customizable": false,
        "fragile": false,
        "can_pack": true,
        "prepared": "plainBackground",
        "photo_provider": "openai",
        "photo_reviewed": true,
        "catalog_plain_background": true,
        "image": "/api/v1/products/images/demo_brass_diya.jpg",
        "original_image": "/api/v1/products/images/demo_brass_diya.jpg"
    }'::jsonb,
    '{}'::jsonb,
    '["brass", "diya", "metalcraft", "dhokra", "pooja"]'::jsonb,
    '["lost-wax casting", "brass casting", "chased engraving"]'::jsonb,
    'शुद्ध पीतल का बना नक्काशीदार दीया',
    'approved',
    NOW(),
    NOW()
);

INSERT INTO price_recommendations (
    id, product_id, material_cost, labour_cost, overhead, craftsmanship_score,
    comparable_ids, recommended_min, recommended_max, final_price,
    explanation_text_en, explanation_text_hi, verification_status, created_at
) VALUES (
    'c1000000-0000-0000-0000-000000000004',
    'a1000000-0000-0000-0000-000000000004',
    210.0, 160.0, 40.0, 0.70,
    '["comp_metal_1"]'::jsonb,
    550.0, 720.0, 620.0,
    '₹550–₹720 recommended because your total cost is ₹410 (brass raw material ₹210 + moulding & polish labour ₹160 + overhead ₹40). Hand-cast brass holds high festive premium.',
    '₹550–₹720 की सिफारिश की जाती है क्योंकि आपकी कुल लागत ₹410 है (पीतल ₹210 + ढलाई व पॉलिश ₹160 + अन्य ₹40)।',
    'approved',
    NOW()
);

INSERT INTO product_images (
    id, product_id, original_url, enhanced_url, verification_status, created_at
) VALUES (
    'd1000000-0000-0000-0000-000000000004',
    'a1000000-0000-0000-0000-000000000004',
    '/api/v1/products/images/demo_brass_diya.jpg',
    '/api/v1/products/images/demo_brass_diya.jpg',
    'approved',
    NOW()
);

COMMIT;

