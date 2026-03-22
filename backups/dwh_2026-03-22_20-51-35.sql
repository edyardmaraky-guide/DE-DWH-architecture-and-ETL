--
-- PostgreSQL database dump
--

\restrict FfUfX7F05aKhDWkuhoRRcUVwu6jKqTS1UlVkAgt2c4sIEKUR8bYvGMrc4MjCuXa

-- Dumped from database version 15.17 (Debian 15.17-1.pgdg13+1)
-- Dumped by pg_dump version 15.17 (Debian 15.17-1.pgdg13+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: load_customers_to_dwh(); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.load_customers_to_dwh()
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- 1. Закрываем старые версии
    UPDATE dwh_dim_customers d
    SET valid_to = CURRENT_TIMESTAMP,
        is_current = FALSE
    FROM tmp_dwh_customers t
    WHERE d.id = t.customer_id
      AND d.is_current = TRUE
      AND (
          d.name <> t.name OR
          d.region <> t.region
      );

    -- 2. Вставляем новые версии
    INSERT INTO dwh_dim_customers (
        id, name, age, age_group, gender, region, valid_from, is_current
    )
    SELECT
        t.customer_id,
        t.name,
		t.age,
		t.age_group,
		t.gender,
		t.region,
        CURRENT_TIMESTAMP,
        TRUE
    FROM tmp_dwh_customers t
    LEFT JOIN dwh_dim_customers d
        ON d.id = t.customer_id
        AND d.is_current = TRUE
    WHERE d.id IS NULL
       OR d.name <> t.name
       OR d.region <> t.region;

EXCEPTION WHEN OTHERS THEN
    INSERT INTO dwh_etl_logs(process_name, step_name, status, error_message)
    VALUES ('customers_load', 'SCD2', 'error', SQLERRM);
END;
$$;


ALTER PROCEDURE public.load_customers_to_dwh() OWNER TO postgres;

--
-- Name: load_products_to_dwh(); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.load_products_to_dwh()
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- 1. Закрываем старые версии
    UPDATE dwh_dim_products d
    SET valid_to = CURRENT_TIMESTAMP,
        is_current = FALSE
    FROM tmp_dwh_products t
    WHERE d.id = t.product_id
      AND d.is_current = TRUE
      AND (
          d.name <> t.product_name OR
          d.category <> t.category
      );

    -- 2. Вставляем новые версии
    INSERT INTO dwh_dim_products (
        id, name, category, cost_price, price_category, valid_from, is_current
    )
    SELECT
        t.product_id,
        t.product_name,
        t.category,
		t.cost_price,
		t.price_category,
        CURRENT_TIMESTAMP,
        TRUE
    FROM tmp_dwh_products t
    LEFT JOIN dwh_dim_products d
        ON d.id = t.product_id
        AND d.is_current = TRUE
    WHERE d.id IS NULL
       OR d.name <> t.product_name
       OR d.category <> t.category;

EXCEPTION WHEN OTHERS THEN
    INSERT INTO dwh_etl_logs(process_name, step_name, status, error_message)
    VALUES ('products_load', 'SCD2', 'error', SQLERRM);
END;
$$;


ALTER PROCEDURE public.load_products_to_dwh() OWNER TO postgres;

--
-- Name: load_sales_to_dwh(); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.load_sales_to_dwh()
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO dwh_fact_sales (
        sales_id,
        customer_id,
        product_id,
        dates,
        quantity,
        price,
        discount,
        gross_revenue,
        net_revenue,
        is_discounted,
        day_of_week,
        month_number,
        year_number,
        updated_at
    )
    SELECT
        sales_id,
        customer_id,
        product_id,
        dates,
        quantity,
        price,
        discount,
        gross_revenue,
        net_revenue,
        is_discounted,
        day_of_week,
        month_number,
        year_number,
        updated_at
    FROM tmp_dwh_sales
    ON CONFLICT (sales_id)
    DO UPDATE SET
        quantity = EXCLUDED.quantity,
        price = EXCLUDED.price,
        discount = EXCLUDED.discount,
        gross_revenue = EXCLUDED.gross_revenue,
        net_revenue = EXCLUDED.net_revenue,
        is_discounted = EXCLUDED.is_discounted,
        updated_at = EXCLUDED.updated_at;

EXCEPTION WHEN OTHERS THEN
    INSERT INTO dwh_etl_logs(process_name, step_name, status, error_message)
    VALUES ('sales_load', 'FACT', 'error', SQLERRM);
END;
$$;


ALTER PROCEDURE public.load_sales_to_dwh() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: dwh_dim_customers; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.dwh_dim_customers (
    id integer NOT NULL,
    name text,
    age integer,
    age_group character varying(10),
    gender character varying(5),
    region text,
    valid_from timestamp without time zone NOT NULL,
    valid_to timestamp without time zone,
    is_current boolean DEFAULT true
);


ALTER TABLE public.dwh_dim_customers OWNER TO postgres;

--
-- Name: dwh_dim_customers_current; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.dwh_dim_customers_current AS
 SELECT dwh_dim_customers.id,
    dwh_dim_customers.name,
    dwh_dim_customers.age,
    dwh_dim_customers.age_group,
    dwh_dim_customers.gender,
    dwh_dim_customers.region,
    dwh_dim_customers.valid_from,
    dwh_dim_customers.valid_to,
    dwh_dim_customers.is_current
   FROM public.dwh_dim_customers
  WHERE (dwh_dim_customers.is_current = true);


ALTER TABLE public.dwh_dim_customers_current OWNER TO postgres;

--
-- Name: dwh_dim_products; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.dwh_dim_products (
    id integer NOT NULL,
    name text,
    category text,
    cost_price numeric(10,2),
    price_category character varying(20),
    valid_from timestamp without time zone NOT NULL,
    valid_to timestamp without time zone,
    is_current boolean DEFAULT true
);


ALTER TABLE public.dwh_dim_products OWNER TO postgres;

--
-- Name: dwh_dim_products_current; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.dwh_dim_products_current AS
 SELECT dwh_dim_products.id,
    dwh_dim_products.name,
    dwh_dim_products.category,
    dwh_dim_products.cost_price,
    dwh_dim_products.price_category,
    dwh_dim_products.valid_from,
    dwh_dim_products.valid_to,
    dwh_dim_products.is_current
   FROM public.dwh_dim_products
  WHERE (dwh_dim_products.is_current = true);


ALTER TABLE public.dwh_dim_products_current OWNER TO postgres;

--
-- Name: dwh_etl_logs; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.dwh_etl_logs (
    id integer NOT NULL,
    process_name character varying(100),
    step_name character varying(100),
    status character varying(20),
    start_time timestamp without time zone,
    end_time timestamp without time zone,
    duration_seconds integer,
    error_message text,
    records_processed integer
);


ALTER TABLE public.dwh_etl_logs OWNER TO postgres;

--
-- Name: dwh_etl_logs_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.dwh_etl_logs_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.dwh_etl_logs_id_seq OWNER TO postgres;

--
-- Name: dwh_etl_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.dwh_etl_logs_id_seq OWNED BY public.dwh_etl_logs.id;


--
-- Name: dwh_fact_sales; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.dwh_fact_sales (
    sales_id integer NOT NULL,
    customer_id integer,
    product_id integer,
    dates date,
    quantity integer,
    price numeric(10,2),
    discount numeric(10,2),
    gross_revenue numeric(10,2),
    net_revenue numeric(10,2),
    is_discounted boolean,
    day_of_week smallint,
    month_number smallint,
    year_number smallint,
    updated_at timestamp without time zone,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.dwh_fact_sales OWNER TO postgres;

--
-- Name: dwh_high_water_mark; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.dwh_high_water_mark (
    id integer NOT NULL,
    table_name character varying(50) NOT NULL,
    last_updated timestamp without time zone,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.dwh_high_water_mark OWNER TO postgres;

--
-- Name: dwh_high_water_mark_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.dwh_high_water_mark_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.dwh_high_water_mark_id_seq OWNER TO postgres;

--
-- Name: dwh_high_water_mark_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.dwh_high_water_mark_id_seq OWNED BY public.dwh_high_water_mark.id;


--
-- Name: dwh_etl_logs id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dwh_etl_logs ALTER COLUMN id SET DEFAULT nextval('public.dwh_etl_logs_id_seq'::regclass);


--
-- Name: dwh_high_water_mark id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dwh_high_water_mark ALTER COLUMN id SET DEFAULT nextval('public.dwh_high_water_mark_id_seq'::regclass);


--
-- Data for Name: dwh_dim_customers; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.dwh_dim_customers (id, name, age, age_group, gender, region, valid_from, valid_to, is_current) FROM stdin;
1	jack allen	28	young	F	West Coast	2026-03-22 17:49:44.629007	\N	t
2	xander jones	66	senior	F	Midwest	2026-03-22 17:49:44.629007	\N	t
3	tina parker	65	senior	F	West Coast	2026-03-22 17:49:44.629007	\N	t
4	paul green	45	adult	M	North	2026-03-22 17:49:44.629007	\N	t
5	quinn adams	69	senior	M	West Coast	2026-03-22 17:49:44.629007	\N	t
6	grace hall	56	senior	F	East Coast	2026-03-22 17:49:44.629007	\N	t
7	emily adams	62	senior	F	West Coast	2026-03-22 17:49:44.629007	\N	t
8	mia allen	61	senior	M	East Coast	2026-03-22 17:49:44.629007	\N	t
9	tina brown	40	adult	M	East Coast	2026-03-22 17:49:44.629007	\N	t
10	grace white	37	adult	F	East Coast	2026-03-22 17:49:44.629007	\N	t
11	frank wright	55	senior	M	North	2026-03-22 17:49:44.629007	\N	t
12	frank young	23	young	F	South	2026-03-22 17:49:44.629007	\N	t
13	victor baker	70	senior	F	Midwest	2026-03-22 17:49:44.629007	\N	t
14	dan clark	43	adult	M	East Coast	2026-03-22 17:49:44.629007	\N	t
15	henry parker	70	senior	F	South	2026-03-22 17:49:44.629007	\N	t
16	uma jones	66	senior	F	East Coast	2026-03-22 17:49:44.629007	\N	t
17	mia brown	55	senior	M	West Coast	2026-03-22 17:49:44.629007	\N	t
18	emily walker	68	senior	F	East Coast	2026-03-22 17:49:44.629007	\N	t
19	alice hall	35	adult	F	Midwest	2026-03-22 17:49:44.629007	\N	t
20	zoe adams	19	young	F	Midwest	2026-03-22 17:49:44.629007	\N	t
21	grace brown	51	senior	F	South	2026-03-22 17:49:44.629007	\N	t
22	nina taylor	60	senior	F	South	2026-03-22 17:49:44.629007	\N	t
23	uma hall	65	senior	M	North	2026-03-22 17:49:44.629007	\N	t
24	nina baker	54	senior	F	East Coast	2026-03-22 17:49:44.629007	\N	t
25	sam smith	37	adult	M	Midwest	2026-03-22 17:49:44.629007	\N	t
26	nina allen	24	young	M	South	2026-03-22 17:49:44.629007	\N	t
27	sam wright	68	senior	M	South	2026-03-22 17:49:44.629007	\N	t
28	oscar green	24	young	M	South	2026-03-22 17:49:44.629007	\N	t
29	quinn taylor	38	adult	M	West Coast	2026-03-22 17:49:44.629007	\N	t
30	leo carter	54	senior	M	East Coast	2026-03-22 17:49:44.629007	\N	t
31	dan white	29	young	F	Midwest	2026-03-22 17:49:44.629007	\N	t
32	bob allen	34	adult	F	North	2026-03-22 17:49:44.629007	\N	t
33	grace mitchell	54	senior	M	West Coast	2026-03-22 17:49:44.629007	\N	t
34	alice king	23	young	F	East Coast	2026-03-22 17:49:44.629007	\N	t
35	jack hill	41	adult	M	East Coast	2026-03-22 17:49:44.629007	\N	t
36	uma brown	39	adult	M	North	2026-03-22 17:49:44.629007	\N	t
37	dan white	21	young	F	Midwest	2026-03-22 17:49:44.629007	\N	t
38	wendy allen	63	senior	F	South	2026-03-22 17:49:44.629007	\N	t
39	quinn hall	43	adult	M	East Coast	2026-03-22 17:49:44.629007	\N	t
40	frank white	53	senior	M	South	2026-03-22 17:49:44.629007	\N	t
41	carol jones	40	adult	F	West Coast	2026-03-22 17:49:44.629007	\N	t
42	quinn adams	24	young	F	North	2026-03-22 17:49:44.629007	\N	t
43	uma mitchell	46	adult	M	South	2026-03-22 17:49:44.629007	\N	t
44	oscar adams	21	young	F	South	2026-03-22 17:49:44.629007	\N	t
45	leo green	52	senior	F	Midwest	2026-03-22 17:49:44.629007	\N	t
46	mia jones	56	senior	M	East Coast	2026-03-22 17:49:44.629007	\N	t
47	leo young	53	senior	M	South	2026-03-22 17:49:44.629007	\N	t
48	yara walker	21	young	M	North	2026-03-22 17:49:44.629007	\N	t
49	victor brown	48	adult	M	Midwest	2026-03-22 17:49:44.629007	\N	t
50	emily lee	70	senior	M	East Coast	2026-03-22 17:49:44.629007	\N	t
51	yara young	66	senior	M	West Coast	2026-03-22 17:49:44.629007	\N	t
52	jack allen	31	adult	M	North	2026-03-22 17:49:44.629007	\N	t
53	emily young	68	senior	M	North	2026-03-22 17:49:44.629007	\N	t
54	alice allen	62	senior	F	Midwest	2026-03-22 17:49:44.629007	\N	t
55	yara walker	58	senior	F	Midwest	2026-03-22 17:49:44.629007	\N	t
56	carol lee	20	young	F	Midwest	2026-03-22 17:49:44.629007	\N	t
57	sam hall	51	senior	M	North	2026-03-22 17:49:44.629007	\N	t
58	zoe carter	51	senior	M	West Coast	2026-03-22 17:49:44.629007	\N	t
59	yara lee	36	adult	M	North	2026-03-22 17:49:44.629007	\N	t
60	alice adams	38	adult	M	East Coast	2026-03-22 17:49:44.629007	\N	t
61	paul young	62	senior	M	Midwest	2026-03-22 17:49:44.629007	\N	t
62	henry parker	68	senior	M	West Coast	2026-03-22 17:49:44.629007	\N	t
63	karen wright	26	young	M	West Coast	2026-03-22 17:49:44.629007	\N	t
64	frank clark	32	adult	M	South	2026-03-22 17:49:44.629007	\N	t
65	quinn hall	64	senior	M	East Coast	2026-03-22 17:49:44.629007	\N	t
66	sam brown	32	adult	M	South	2026-03-22 17:49:44.629007	\N	t
67	rachel hill	61	senior	M	East Coast	2026-03-22 17:49:44.629007	\N	t
68	rachel hill	51	senior	M	South	2026-03-22 17:49:44.629007	\N	t
69	rachel brown	44	adult	F	West Coast	2026-03-22 17:49:44.629007	\N	t
70	nina lee	33	adult	F	Midwest	2026-03-22 17:49:44.629007	\N	t
71	paul lee	19	young	F	West Coast	2026-03-22 17:49:44.629007	\N	t
72	carol brown	37	adult	M	West Coast	2026-03-22 17:49:44.629007	\N	t
73	mia allen	36	adult	M	East Coast	2026-03-22 17:49:44.629007	\N	t
74	carol parker	32	adult	M	South	2026-03-22 17:49:44.629007	\N	t
75	frank parker	50	adult	M	East Coast	2026-03-22 17:49:44.629007	\N	t
76	grace white	51	senior	M	West Coast	2026-03-22 17:49:44.629007	\N	t
77	frank young	38	adult	F	South	2026-03-22 17:49:44.629007	\N	t
78	alice hill	64	senior	M	North	2026-03-22 17:49:44.629007	\N	t
79	dan walker	23	young	F	Midwest	2026-03-22 17:49:44.629007	\N	t
80	bob allen	58	senior	M	East Coast	2026-03-22 17:49:44.629007	\N	t
81	jack young	59	senior	M	South	2026-03-22 17:49:44.629007	\N	t
82	quinn lee	34	adult	M	South	2026-03-22 17:49:44.629007	\N	t
83	emily brown	44	adult	M	East Coast	2026-03-22 17:49:44.629007	\N	t
84	frank brown	36	adult	M	East Coast	2026-03-22 17:49:44.629007	\N	t
85	rachel green	20	young	F	North	2026-03-22 17:49:44.629007	\N	t
86	emily king	31	adult	F	Midwest	2026-03-22 17:49:44.629007	\N	t
87	nina young	52	senior	F	East Coast	2026-03-22 17:49:44.629007	\N	t
88	emily adams	59	senior	F	East Coast	2026-03-22 17:49:44.629007	\N	t
89	tina clark	43	adult	F	North	2026-03-22 17:49:44.629007	\N	t
90	carol brown	41	adult	M	North	2026-03-22 17:49:44.629007	\N	t
91	uma lee	67	senior	F	Midwest	2026-03-22 17:49:44.629007	\N	t
92	xander walker	54	senior	F	North	2026-03-22 17:49:44.629007	\N	t
93	rachel taylor	32	adult	M	Midwest	2026-03-22 17:49:44.629007	\N	t
94	dan lee	18	child	F	West Coast	2026-03-22 17:49:44.629007	\N	t
95	tina taylor	52	senior	F	South	2026-03-22 17:49:44.629007	\N	t
96	quinn hall	59	senior	F	South	2026-03-22 17:49:44.629007	\N	t
97	henry parker	18	child	F	North	2026-03-22 17:49:44.629007	\N	t
98	henry hall	60	senior	F	Midwest	2026-03-22 17:49:44.629007	\N	t
99	rachel lee	67	senior	F	West Coast	2026-03-22 17:49:44.629007	\N	t
100	paul wright	68	senior	M	East Coast	2026-03-22 17:49:44.629007	\N	t
101	karen hill	69	senior	F	East Coast	2026-03-22 17:49:44.629007	\N	t
102	isla walker	38	adult	F	South	2026-03-22 17:49:44.629007	\N	t
103	tina allen	23	young	F	West Coast	2026-03-22 17:49:44.629007	\N	t
104	bob young	48	adult	F	West Coast	2026-03-22 17:49:44.629007	\N	t
105	tina young	52	senior	F	West Coast	2026-03-22 17:49:44.629007	\N	t
106	emily green	61	senior	M	North	2026-03-22 17:49:44.629007	\N	t
107	jack hall	68	senior	F	Midwest	2026-03-22 17:49:44.629007	\N	t
108	emily taylor	21	young	M	South	2026-03-22 17:49:44.629007	\N	t
109	oscar clark	62	senior	F	South	2026-03-22 17:49:44.629007	\N	t
110	zoe young	55	senior	M	West Coast	2026-03-22 17:49:44.629007	\N	t
111	grace walker	21	young	F	Midwest	2026-03-22 17:49:44.629007	\N	t
112	frank white	52	senior	F	East Coast	2026-03-22 17:49:44.629007	\N	t
113	paul brown	64	senior	F	South	2026-03-22 17:49:44.629007	\N	t
114	nina carter	59	senior	F	East Coast	2026-03-22 17:49:44.629007	\N	t
115	bob parker	25	young	M	West Coast	2026-03-22 17:49:44.629007	\N	t
116	carol baker	62	senior	M	Midwest	2026-03-22 17:49:44.629007	\N	t
117	isla walker	44	adult	M	South	2026-03-22 17:49:44.629007	\N	t
118	jack adams	53	senior	M	Midwest	2026-03-22 17:49:44.629007	\N	t
119	zoe hill	41	adult	F	Midwest	2026-03-22 17:49:44.629007	\N	t
120	leo brown	70	senior	F	West Coast	2026-03-22 17:49:44.629007	\N	t
121	leo carter	65	senior	M	Midwest	2026-03-22 17:49:44.629007	\N	t
122	mia clark	40	adult	M	Midwest	2026-03-22 17:49:44.629007	\N	t
123	rachel young	22	young	F	West Coast	2026-03-22 17:49:44.629007	\N	t
124	rachel allen	24	young	F	North	2026-03-22 17:49:44.629007	\N	t
125	jack clark	59	senior	M	Midwest	2026-03-22 17:49:44.629007	\N	t
126	isla walker	20	young	M	North	2026-03-22 17:49:44.629007	\N	t
127	nina white	67	senior	F	Midwest	2026-03-22 17:49:44.629007	\N	t
128	xander carter	42	adult	M	Midwest	2026-03-22 17:49:44.629007	\N	t
129	xander jones	20	young	F	North	2026-03-22 17:49:44.629007	\N	t
130	alice king	60	senior	M	Midwest	2026-03-22 17:49:44.629007	\N	t
131	uma young	43	adult	F	Midwest	2026-03-22 17:49:44.629007	\N	t
132	paul wright	66	senior	M	North	2026-03-22 17:49:44.629007	\N	t
133	bob smith	19	young	M	Midwest	2026-03-22 17:49:44.629007	\N	t
134	yara hill	36	adult	M	North	2026-03-22 17:49:44.629007	\N	t
135	rachel young	41	adult	F	West Coast	2026-03-22 17:49:44.629007	\N	t
136	henry mitchell	54	senior	M	Midwest	2026-03-22 17:49:44.629007	\N	t
137	uma young	19	young	M	East Coast	2026-03-22 17:49:44.629007	\N	t
138	sam parker	18	child	M	North	2026-03-22 17:49:44.629007	\N	t
139	nina young	53	senior	M	North	2026-03-22 17:49:44.629007	\N	t
140	wendy hall	28	young	F	East Coast	2026-03-22 17:49:44.629007	\N	t
141	mia smith	43	adult	F	Midwest	2026-03-22 17:49:44.629007	\N	t
142	henry hill	36	adult	M	Midwest	2026-03-22 17:49:44.629007	\N	t
143	yara hall	19	young	F	Midwest	2026-03-22 17:49:44.629007	\N	t
144	karen allen	56	senior	F	West Coast	2026-03-22 17:49:44.629007	\N	t
145	grace parker	55	senior	M	North	2026-03-22 17:49:44.629007	\N	t
146	dan allen	64	senior	M	North	2026-03-22 17:49:44.629007	\N	t
147	karen hall	66	senior	F	West Coast	2026-03-22 17:49:44.629007	\N	t
148	bob brown	64	senior	F	South	2026-03-22 17:49:44.629007	\N	t
149	frank carter	42	adult	F	South	2026-03-22 17:49:44.629007	\N	t
150	wendy lee	24	young	M	South	2026-03-22 17:49:44.629007	\N	t
\.


--
-- Data for Name: dwh_dim_products; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.dwh_dim_products (id, name, category, cost_price, price_category, valid_from, valid_to, is_current) FROM stdin;
1	widget a	electronics	15.00	medium	2026-03-22 17:49:44.624296	\N	t
2	gadget b	home appliances	25.00	expensive	2026-03-22 17:49:44.624296	\N	t
3	tool c	hardware	10.00	cheap	2026-03-22 17:49:44.624296	\N	t
4	accessory d	accessories	5.00	cheap	2026-03-22 17:49:44.624296	\N	t
5	device e	electronics	30.00	expensive	2026-03-22 17:49:44.624296	\N	t
6	item f	office supplies	12.50	medium	2026-03-22 17:49:44.624296	\N	t
7	appliance g	home appliances	45.00	expensive	2026-03-22 17:49:44.624296	\N	t
8	widget h	electronics	20.00	expensive	2026-03-22 17:49:44.624296	\N	t
9	tool i	hardware	18.00	medium	2026-03-22 17:49:44.624296	\N	t
10	accessory j	accessories	7.50	cheap	2026-03-22 17:49:44.624296	\N	t
11	widget k	electronics	16.00	medium	2026-03-22 17:49:44.624296	\N	t
12	gadget l	home appliances	22.00	expensive	2026-03-22 17:49:44.624296	\N	t
13	tool m	hardware	11.50	medium	2026-03-22 17:49:44.624296	\N	t
14	accessory n	accessories	6.00	cheap	2026-03-22 17:49:44.624296	\N	t
15	device o	electronics	35.00	expensive	2026-03-22 17:49:44.624296	\N	t
16	item p	office supplies	13.00	medium	2026-03-22 17:49:44.624296	\N	t
17	appliance q	home appliances	40.00	expensive	2026-03-22 17:49:44.624296	\N	t
18	widget r	electronics	21.50	expensive	2026-03-22 17:49:44.624296	\N	t
19	tool s	hardware	19.00	medium	2026-03-22 17:49:44.624296	\N	t
20	accessory t	accessories	8.50	cheap	2026-03-22 17:49:44.624296	\N	t
21	widget u	electronics	17.00	medium	2026-03-22 17:49:44.624296	\N	t
22	gadget v	home appliances	27.00	expensive	2026-03-22 17:49:44.624296	\N	t
23	tool w	hardware	12.00	medium	2026-03-22 17:49:44.624296	\N	t
24	accessory x	accessories	5.50	cheap	2026-03-22 17:49:44.624296	\N	t
25	device y	electronics	32.50	expensive	2026-03-22 17:49:44.624296	\N	t
26	item z	office supplies	11.00	medium	2026-03-22 17:49:44.624296	\N	t
27	appliance aa	home appliances	42.50	expensive	2026-03-22 17:49:44.624296	\N	t
28	widget ab	electronics	23.00	expensive	2026-03-22 17:49:44.624296	\N	t
29	tool ac	hardware	20.00	expensive	2026-03-22 17:49:44.624296	\N	t
30	accessory ad	accessories	9.00	cheap	2026-03-22 17:49:44.624296	\N	t
31	widget ae	electronics	18.50	medium	2026-03-22 17:49:44.624296	\N	t
32	gadget af	home appliances	24.00	expensive	2026-03-22 17:49:44.624296	\N	t
33	tool ag	hardware	10.50	medium	2026-03-22 17:49:44.624296	\N	t
34	accessory ah	accessories	4.75	cheap	2026-03-22 17:49:44.624296	\N	t
35	device ai	electronics	31.50	expensive	2026-03-22 17:49:44.624296	\N	t
36	item aj	office supplies	13.25	medium	2026-03-22 17:49:44.624296	\N	t
37	appliance ak	home appliances	44.00	expensive	2026-03-22 17:49:44.624296	\N	t
38	widget al	electronics	19.50	medium	2026-03-22 17:49:44.624296	\N	t
39	tool am	hardware	17.50	medium	2026-03-22 17:49:44.624296	\N	t
40	accessory an	accessories	6.50	cheap	2026-03-22 17:49:44.624296	\N	t
41	widget ao	electronics	16.75	medium	2026-03-22 17:49:44.624296	\N	t
42	gadget ap	home appliances	26.50	expensive	2026-03-22 17:49:44.624296	\N	t
43	tool aq	hardware	14.00	medium	2026-03-22 17:49:44.624296	\N	t
44	accessory ar	accessories	5.25	cheap	2026-03-22 17:49:44.624296	\N	t
45	device as	electronics	29.75	expensive	2026-03-22 17:49:44.624296	\N	t
46	item at	office supplies	12.75	medium	2026-03-22 17:49:44.624296	\N	t
47	appliance au	home appliances	41.25	expensive	2026-03-22 17:49:44.624296	\N	t
48	widget av	electronics	22.25	expensive	2026-03-22 17:49:44.624296	\N	t
49	tool aw	hardware	19.75	medium	2026-03-22 17:49:44.624296	\N	t
50	accessory ax	accessories	8.75	cheap	2026-03-22 17:49:44.624296	\N	t
51	widget ay	electronics	15.75	medium	2026-03-22 17:49:44.624296	\N	t
52	gadget az	home appliances	23.75	expensive	2026-03-22 17:49:44.624296	\N	t
53	tool ba	hardware	11.25	medium	2026-03-22 17:49:44.624296	\N	t
\.


--
-- Data for Name: dwh_etl_logs; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.dwh_etl_logs (id, process_name, step_name, status, start_time, end_time, duration_seconds, error_message, records_processed) FROM stdin;
\.


--
-- Data for Name: dwh_fact_sales; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.dwh_fact_sales (sales_id, customer_id, product_id, dates, quantity, price, discount, gross_revenue, net_revenue, is_discounted, day_of_week, month_number, year_number, updated_at, created_at) FROM stdin;
1086	107	44	2024-01-05	10	10.50	0.00	105.00	105.00	f	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1001	1	1	2024-01-01	2	20.00	0.05	40.00	38.00	t	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1002	2	2	2024-01-01	1	35.00	0.10	35.00	31.50	t	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1003	1	3	2024-01-01	3	15.00	0.00	45.00	45.00	f	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1004	56	5	2024-01-01	4	35.00	0.05	140.00	133.00	t	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1005	35	50	2024-01-01	1	20.00	0.06	20.00	18.80	t	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1006	48	41	2024-01-01	6	33.50	0.04	201.00	192.96	t	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1007	4	21	2024-01-01	8	34.00	0.10	272.00	244.80	t	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1008	147	51	2024-01-01	7	31.50	0.09	220.50	200.66	t	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1009	80	39	2024-01-01	8	35.00	0.09	280.00	254.80	t	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1010	62	32	2024-01-01	9	48.00	0.02	432.00	423.36	t	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1011	126	14	2024-01-01	9	12.00	0.04	108.00	103.68	t	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1012	95	1	2024-01-01	7	30.00	0.02	210.00	205.80	t	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1013	23	9	2024-01-01	2	36.00	0.02	72.00	70.56	t	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1014	101	22	2024-01-01	4	54.00	0.04	216.00	207.36	t	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1015	13	38	2024-01-01	9	39.00	0.07	351.00	326.43	t	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1016	15	21	2024-01-01	6	34.00	0.08	204.00	187.68	t	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1017	87	44	2024-01-01	10	10.50	0.08	105.00	96.60	t	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1018	39	44	2024-01-01	10	10.50	0.03	105.00	101.85	t	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1019	108	9	2024-01-01	5	36.00	0.02	180.00	176.40	t	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1020	17	38	2024-01-01	5	39.00	0.02	195.00	191.10	t	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1021	10	1	2024-01-02	4	30.00	0.04	120.00	115.20	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1022	104	44	2024-01-02	3	10.50	0.09	31.50	28.67	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1023	109	36	2024-01-02	10	26.50	0.01	265.00	262.35	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1024	16	35	2024-01-02	6	63.00	0.06	378.00	355.32	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1025	97	32	2024-01-02	3	48.00	0.05	144.00	136.80	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1026	105	53	2024-01-02	4	22.50	0.07	90.00	83.70	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1027	125	42	2024-01-02	1	53.00	0.06	53.00	49.82	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1028	72	24	2024-01-02	7	11.00	0.02	77.00	75.46	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1029	2	22	2024-01-02	1	54.00	0.06	54.00	50.76	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1030	144	48	2024-01-02	4	44.50	0.08	178.00	163.76	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1031	104	45	2024-01-02	4	59.50	0.10	238.00	214.20	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1032	118	19	2024-01-02	5	38.00	0.01	190.00	188.10	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1033	133	17	2024-01-02	6	80.00	0.07	480.00	446.40	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1034	61	24	2024-01-02	1	11.00	0.02	11.00	10.78	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1035	77	5	2024-01-02	4	60.00	0.07	240.00	223.20	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1036	143	12	2024-01-02	4	44.00	0.02	176.00	172.48	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1037	110	32	2024-01-02	3	48.00	0.06	144.00	135.36	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1038	34	41	2024-01-02	10	33.50	0.04	335.00	321.60	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1039	17	19	2024-01-02	7	38.00	0.06	266.00	250.04	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1040	123	6	2024-01-02	2	25.00	0.10	50.00	45.00	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1041	67	1	2024-01-02	3	30.00	0.09	90.00	81.90	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1042	47	1	2024-01-02	9	30.00	0.05	270.00	256.50	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1043	8	36	2024-01-02	10	26.50	0.01	265.00	262.35	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1044	17	14	2024-01-03	7	12.00	0.01	84.00	83.16	t	2	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1045	137	5	2024-01-03	5	60.00	0.00	300.00	300.00	f	2	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1046	55	45	2024-01-03	4	59.50	0.06	238.00	223.72	t	2	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1047	97	1	2024-01-03	6	30.00	0.06	180.00	169.20	t	2	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1048	81	25	2024-01-03	10	65.00	0.10	650.00	585.00	t	2	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1049	6	50	2024-01-03	10	17.50	0.07	175.00	162.75	t	2	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1050	71	34	2024-01-03	9	9.50	0.02	85.50	83.79	t	2	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1051	41	16	2024-01-03	6	26.00	0.01	156.00	154.44	t	2	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1052	103	37	2024-01-03	10	88.00	0.00	880.00	880.00	f	2	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1053	127	26	2024-01-03	3	22.00	0.07	66.00	61.38	t	2	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1054	87	38	2024-01-03	10	39.00	0.02	390.00	382.20	t	2	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1055	16	3	2024-01-03	9	20.00	0.04	180.00	172.80	t	2	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1056	31	9	2024-01-03	6	36.00	0.05	216.00	205.20	t	2	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1057	124	26	2024-01-04	5	22.00	0.02	110.00	107.80	t	3	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1058	39	16	2024-01-04	6	26.00	0.07	156.00	145.08	t	3	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1059	141	22	2024-01-04	10	54.00	0.05	540.00	513.00	t	3	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1060	103	18	2024-01-04	5	43.00	0.09	215.00	195.65	t	3	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1061	37	6	2024-01-04	2	25.00	0.05	50.00	47.50	t	3	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1062	34	8	2024-01-04	8	40.00	0.08	320.00	294.40	t	3	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1063	147	50	2024-01-04	7	17.50	0.03	122.50	118.83	t	3	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1064	143	27	2024-01-04	2	85.00	0.03	170.00	164.90	t	3	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1065	41	34	2024-01-04	10	9.50	0.06	95.00	89.30	t	3	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1066	61	1	2024-01-04	10	30.00	0.02	300.00	294.00	t	3	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1067	20	15	2024-01-04	6	70.00	0.07	420.00	390.60	t	3	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1068	32	49	2024-01-04	3	39.50	0.08	118.50	109.02	t	3	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1069	35	6	2024-01-04	10	25.00	0.01	250.00	247.50	t	3	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1070	121	12	2024-01-04	7	44.00	0.04	308.00	295.68	t	3	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1071	5	20	2024-01-04	7	17.00	0.04	119.00	114.24	t	3	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1072	73	21	2024-01-04	10	34.00	0.02	340.00	333.20	t	3	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1073	123	6	2024-01-04	10	25.00	0.00	250.00	250.00	f	3	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1074	66	15	2024-01-04	1	70.00	0.08	70.00	64.40	t	3	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1075	129	42	2024-01-04	9	53.00	0.04	477.00	457.92	t	3	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1076	24	41	2024-01-05	6	33.50	0.04	201.00	192.96	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1077	139	28	2024-01-05	8	46.00	0.07	368.00	342.24	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1078	139	23	2024-01-05	3	24.00	0.08	72.00	66.24	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1079	147	32	2024-01-05	9	48.00	0.01	432.00	427.68	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1080	88	27	2024-01-05	3	85.00	0.01	255.00	252.45	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1081	55	2	2024-01-05	7	50.00	0.09	350.00	318.50	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1082	37	26	2024-01-05	4	22.00	0.01	88.00	87.12	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1083	30	42	2024-01-05	10	53.00	0.09	530.00	482.30	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1084	17	29	2024-01-05	8	40.00	0.04	320.00	307.20	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1085	74	4	2024-01-05	9	10.00	0.08	90.00	82.80	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1087	117	31	2024-01-05	2	37.00	0.06	74.00	69.56	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1088	101	12	2024-01-05	8	44.00	0.00	352.00	352.00	f	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1089	143	48	2024-01-05	8	44.50	0.05	356.00	338.20	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1090	48	10	2024-01-05	6	15.00	0.08	90.00	82.80	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1091	10	21	2024-01-05	10	34.00	0.02	340.00	333.20	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1092	103	35	2024-01-05	9	63.00	0.03	567.00	549.99	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1093	61	13	2024-01-05	2	23.00	0.03	46.00	44.62	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1094	65	43	2024-01-05	6	28.00	0.05	168.00	159.60	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1095	91	45	2024-01-05	1	59.50	0.07	59.50	55.33	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1096	106	45	2024-01-06	10	59.50	0.07	595.00	553.35	t	5	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1097	143	50	2024-01-06	7	17.50	0.02	122.50	120.05	t	5	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1098	115	19	2024-01-06	6	38.00	0.01	228.00	225.72	t	5	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1099	125	2	2024-01-06	8	50.00	0.09	400.00	364.00	t	5	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1100	64	26	2024-01-06	8	22.00	0.07	176.00	163.68	t	5	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1101	39	35	2024-01-06	6	63.00	0.07	378.00	351.54	t	5	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1102	83	39	2024-01-06	6	35.00	0.01	210.00	207.90	t	5	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1103	149	52	2024-01-06	1	47.50	0.02	47.50	46.55	t	5	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1104	22	26	2024-01-06	3	22.00	0.01	66.00	65.34	t	5	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1105	73	30	2024-01-06	4	18.00	0.04	72.00	69.12	t	5	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1106	2	53	2024-01-06	8	22.50	0.00	180.00	180.00	f	5	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1107	96	2	2024-01-06	2	50.00	0.04	100.00	96.00	t	5	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1108	9	21	2024-01-06	7	34.00	0.08	238.00	218.96	t	5	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1109	130	13	2024-01-06	8	23.00	0.05	184.00	174.80	t	5	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1110	123	26	2024-01-06	4	22.00	0.02	88.00	86.24	t	5	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1111	85	1	2024-01-06	4	30.00	0.02	120.00	117.60	t	5	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1112	95	43	2024-01-06	2	28.00	0.02	56.00	54.88	t	5	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1113	34	8	2024-01-06	9	40.00	0.05	360.00	342.00	t	5	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1114	143	49	2024-01-06	2	39.50	0.06	79.00	74.26	t	5	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1115	130	15	2024-01-06	8	70.00	0.09	560.00	509.60	t	5	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1116	136	1	2024-01-07	5	30.00	0.04	150.00	144.00	t	6	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1117	10	2	2024-01-07	8	50.00	0.08	400.00	368.00	t	6	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1118	98	12	2024-01-07	7	44.00	0.10	308.00	277.20	t	6	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1119	60	30	2024-01-07	5	18.00	0.05	90.00	85.50	t	6	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1120	15	4	2024-01-07	2	10.00	0.04	20.00	19.20	t	6	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1121	61	52	2024-01-07	1	47.50	0.03	47.50	46.07	t	6	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1122	128	44	2024-01-07	2	10.50	0.03	21.00	20.37	t	6	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1123	41	14	2024-01-07	2	12.00	0.00	24.00	24.00	f	6	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1124	52	9	2024-01-07	2	36.00	0.06	72.00	67.68	t	6	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1125	140	32	2024-01-07	1	48.00	0.05	48.00	45.60	t	6	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1126	2	18	2024-01-07	10	43.00	0.01	430.00	425.70	t	6	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1127	9	34	2024-01-07	8	9.50	0.07	76.00	70.68	t	6	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1128	93	6	2024-01-07	2	25.00	0.02	50.00	49.00	t	6	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1129	126	46	2024-01-07	9	25.50	0.06	229.50	215.73	t	6	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1130	134	53	2024-01-07	1	22.50	0.01	22.50	22.28	t	6	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1131	142	47	2024-01-07	5	82.50	0.08	412.50	379.50	t	6	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1132	117	10	2024-01-07	5	15.00	0.01	75.00	74.25	t	6	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1133	100	27	2024-01-08	1	85.00	0.09	85.00	77.35	t	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1134	86	52	2024-01-08	3	47.50	0.03	142.50	138.23	t	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1135	29	32	2024-01-08	9	48.00	0.01	432.00	427.68	t	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1136	67	18	2024-01-08	2	43.00	0.03	86.00	83.42	t	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1137	60	45	2024-01-08	4	59.50	0.01	238.00	235.62	t	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1138	103	12	2024-01-08	8	44.00	0.00	352.00	352.00	f	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1139	57	6	2024-01-08	1	25.00	0.03	25.00	24.25	t	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1140	13	44	2024-01-08	9	10.50	0.03	94.50	91.66	t	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1141	11	12	2024-01-08	9	44.00	0.03	396.00	384.12	t	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1142	86	24	2024-01-08	5	11.00	0.02	55.00	53.90	t	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1143	94	47	2024-01-08	6	82.50	0.10	495.00	445.50	t	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1144	136	15	2024-01-08	10	70.00	0.03	700.00	679.00	t	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1145	4	20	2024-01-08	4	17.00	0.09	68.00	61.88	t	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1146	49	8	2024-01-08	7	40.00	0.02	280.00	274.40	t	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1147	2	21	2024-01-08	9	34.00	0.03	306.00	296.82	t	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1148	141	43	2024-01-08	5	28.00	0.05	140.00	133.00	t	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1149	42	52	2024-01-08	5	47.50	0.01	237.50	235.13	t	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1150	135	7	2024-01-08	2	90.00	0.04	180.00	172.80	t	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1151	67	7	2024-01-08	7	90.00	0.07	630.00	585.90	t	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1152	3	7	2024-01-09	2	90.00	0.09	180.00	163.80	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1153	35	38	2024-01-09	6	39.00	0.01	234.00	231.66	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1154	133	39	2024-01-09	2	35.00	0.02	70.00	68.60	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1155	117	31	2024-01-09	1	37.00	0.01	37.00	36.63	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1156	23	8	2024-01-09	9	40.00	0.00	360.00	360.00	f	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1157	89	48	2024-01-09	8	44.50	0.08	356.00	327.52	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1158	73	42	2024-01-09	1	53.00	0.09	53.00	48.23	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1159	7	47	2024-01-09	10	82.50	0.01	825.00	816.75	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1160	84	10	2024-01-09	1	15.00	0.00	15.00	15.00	f	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1161	91	1	2024-01-09	8	30.00	0.09	240.00	218.40	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1162	98	2	2024-01-09	8	50.00	0.05	400.00	380.00	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1163	86	10	2024-01-09	2	15.00	0.06	30.00	28.20	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1164	66	51	2024-01-09	6	31.50	0.05	189.00	179.55	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1165	7	48	2024-01-09	1	44.50	0.10	44.50	40.05	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1166	12	12	2024-01-09	6	44.00	0.10	264.00	237.60	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1167	61	30	2024-01-09	7	18.00	0.07	126.00	117.18	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1168	106	42	2024-01-09	3	53.00	0.02	159.00	155.82	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1169	93	18	2024-01-10	6	43.00	0.03	258.00	250.26	t	2	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1170	10	17	2024-01-10	9	80.00	0.00	720.00	720.00	f	2	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1171	96	52	2024-01-10	7	47.50	0.04	332.50	319.20	t	2	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1172	125	44	2024-01-10	9	10.50	0.01	94.50	93.55	t	2	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1173	82	25	2024-01-10	5	65.00	0.08	325.00	299.00	t	2	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1174	37	50	2024-01-10	5	17.50	0.08	87.50	80.50	t	2	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1175	145	8	2024-01-10	1	40.00	0.02	40.00	39.20	t	2	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1176	77	6	2024-01-10	9	25.00	0.03	225.00	218.25	t	2	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1177	109	9	2024-01-10	9	36.00	0.05	324.00	307.80	t	2	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1178	88	19	2024-01-10	3	38.00	0.05	114.00	108.30	t	2	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1179	121	23	2024-01-10	4	24.00	0.09	96.00	87.36	t	2	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1180	56	30	2024-01-10	4	18.00	0.00	72.00	72.00	f	2	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1181	18	36	2024-01-10	8	26.50	0.04	212.00	203.52	t	2	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1182	109	41	2024-01-11	4	33.50	0.10	134.00	120.60	t	3	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1183	78	35	2024-01-11	2	63.00	0.08	126.00	115.92	t	3	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1184	150	1	2024-01-11	5	30.00	0.01	150.00	148.50	t	3	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1185	38	39	2024-01-11	7	35.00	0.09	245.00	222.95	t	3	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1186	140	29	2024-01-11	3	40.00	0.06	120.00	112.80	t	3	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1187	128	42	2024-01-11	10	53.00	0.08	530.00	487.60	t	3	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1188	29	19	2024-01-11	7	38.00	0.06	266.00	250.04	t	3	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1189	87	3	2024-01-11	2	20.00	0.04	40.00	38.40	t	3	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1190	35	12	2024-01-11	2	44.00	0.01	88.00	87.12	t	3	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1191	99	36	2024-01-11	3	26.50	0.07	79.50	73.93	t	3	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1192	50	7	2024-01-11	5	90.00	0.01	450.00	445.50	t	3	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1193	66	49	2024-01-11	2	39.50	0.07	79.00	73.47	t	3	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1194	15	15	2024-01-11	9	70.00	0.00	630.00	630.00	f	3	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1195	39	51	2024-01-11	5	31.50	0.06	157.50	148.05	t	3	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1196	110	21	2024-01-11	8	34.00	0.02	272.00	266.56	t	3	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1197	131	39	2024-01-11	5	35.00	0.03	175.00	169.75	t	3	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1198	17	29	2024-01-11	4	40.00	0.00	160.00	160.00	f	3	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1199	76	18	2024-01-11	6	43.00	0.03	258.00	250.26	t	3	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1200	122	5	2024-01-12	3	60.00	0.04	180.00	172.80	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1201	130	38	2024-01-12	9	39.00	0.09	351.00	319.41	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1202	69	44	2024-01-12	3	10.50	0.04	31.50	30.24	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1203	63	5	2024-01-12	8	60.00	0.05	480.00	456.00	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1204	44	35	2024-01-12	5	63.00	0.03	315.00	305.55	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1205	3	3	2024-01-12	6	20.00	0.10	120.00	108.00	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1206	55	29	2024-01-12	6	40.00	0.09	240.00	218.40	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1207	80	43	2024-01-12	8	28.00	0.01	224.00	221.76	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1208	69	13	2024-01-12	6	23.00	0.02	138.00	135.24	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1209	129	27	2024-01-12	3	85.00	0.04	255.00	244.80	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1210	97	5	2024-01-12	5	60.00	0.01	300.00	297.00	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1211	103	42	2024-01-12	1	53.00	0.08	53.00	48.76	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1212	119	12	2024-01-12	8	44.00	0.07	352.00	327.36	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1213	108	43	2024-01-12	9	28.00	0.07	252.00	234.36	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1214	78	16	2024-01-12	2	26.00	0.09	52.00	47.32	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1215	77	25	2024-01-12	2	65.00	0.01	130.00	128.70	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1216	22	11	2024-01-12	4	32.00	0.09	128.00	116.48	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1217	59	25	2024-01-12	7	65.00	0.02	455.00	445.90	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1218	27	47	2024-01-12	1	82.50	0.04	82.50	79.20	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1219	85	26	2024-01-12	7	22.00	0.04	154.00	147.84	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1220	70	42	2024-01-12	3	53.00	0.10	159.00	143.10	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1221	127	29	2024-01-12	6	40.00	0.10	240.00	216.00	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1222	108	1	2024-01-13	7	30.00	0.03	210.00	203.70	t	5	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1223	58	8	2024-01-13	3	40.00	0.01	120.00	118.80	t	5	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1224	29	29	2024-01-13	3	40.00	0.10	120.00	108.00	t	5	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1225	70	49	2024-01-13	5	39.50	0.05	197.50	187.63	t	5	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1226	30	47	2024-01-13	1	82.50	0.03	82.50	80.02	t	5	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1227	22	46	2024-01-13	2	25.50	0.00	51.00	51.00	f	5	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1228	122	10	2024-01-13	2	15.00	0.00	30.00	30.00	f	5	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1229	111	13	2024-01-13	3	23.00	0.08	69.00	63.48	t	5	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1230	136	28	2024-01-13	6	46.00	0.08	276.00	253.92	t	5	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1231	20	41	2024-01-13	7	33.50	0.06	234.50	220.43	t	5	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1232	140	24	2024-01-13	10	11.00	0.02	110.00	107.80	t	5	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1233	119	31	2024-01-13	5	37.00	0.03	185.00	179.45	t	5	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1234	113	53	2024-01-13	1	22.50	0.08	22.50	20.70	t	5	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1235	8	16	2024-01-13	9	26.00	0.04	234.00	224.64	t	5	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1236	106	36	2024-01-13	10	26.50	0.00	265.00	265.00	f	5	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1237	125	25	2024-01-13	8	65.00	0.09	520.00	473.20	t	5	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1238	13	40	2024-01-13	9	13.00	0.06	117.00	109.98	t	5	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1239	70	40	2024-01-14	5	13.00	0.08	65.00	59.80	t	6	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1240	9	41	2024-01-14	3	33.50	0.04	100.50	96.48	t	6	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1241	61	48	2024-01-14	8	44.50	0.03	356.00	345.32	t	6	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1242	22	49	2024-01-14	3	39.50	0.02	118.50	116.13	t	6	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1243	139	33	2024-01-14	1	21.00	0.04	21.00	20.16	t	6	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1244	44	20	2024-01-14	3	17.00	0.07	51.00	47.43	t	6	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1245	146	31	2024-01-14	6	37.00	0.07	222.00	206.46	t	6	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1246	137	47	2024-01-14	4	82.50	0.05	330.00	313.50	t	6	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1247	64	49	2024-01-14	1	39.50	0.03	39.50	38.32	t	6	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1248	81	40	2024-01-14	10	13.00	0.05	130.00	123.50	t	6	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1249	91	5	2024-01-14	7	60.00	0.01	420.00	415.80	t	6	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1250	25	14	2024-01-14	1	12.00	0.08	12.00	11.04	t	6	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1251	40	49	2024-01-14	10	39.50	0.06	395.00	371.30	t	6	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1252	24	17	2024-01-14	5	80.00	0.08	400.00	368.00	t	6	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1253	119	45	2024-01-14	6	59.50	0.01	357.00	353.43	t	6	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1254	82	7	2024-01-14	5	90.00	0.07	450.00	418.50	t	6	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1255	130	46	2024-01-14	6	25.50	0.01	153.00	151.47	t	6	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1256	15	29	2024-01-14	3	40.00	0.00	120.00	120.00	f	6	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1257	31	18	2024-01-14	6	43.00	0.10	258.00	232.20	t	6	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1258	79	43	2024-01-14	10	28.00	0.07	280.00	260.40	t	6	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1259	51	26	2024-01-14	9	22.00	0.10	198.00	178.20	t	6	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1260	1	16	2024-01-14	3	26.00	0.10	78.00	70.20	t	6	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1261	95	49	2024-01-14	10	39.50	0.02	395.00	387.10	t	6	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1262	43	4	2024-01-14	9	10.00	0.01	90.00	89.10	t	6	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1263	41	1	2024-01-14	10	30.00	0.08	300.00	276.00	t	6	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1264	4	23	2024-01-14	3	24.00	0.02	72.00	70.56	t	6	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1265	36	52	2024-01-15	4	47.50	0.10	190.00	171.00	t	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1266	92	33	2024-01-15	8	21.00	0.06	168.00	157.92	t	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1267	9	2	2024-01-15	8	50.00	0.06	400.00	376.00	t	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1268	3	47	2024-01-15	5	82.50	0.07	412.50	383.63	t	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1269	16	37	2024-01-15	9	88.00	0.08	792.00	728.64	t	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1270	67	50	2024-01-15	2	17.50	0.06	35.00	32.90	t	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1271	20	45	2024-01-15	4	59.50	0.01	238.00	235.62	t	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1272	144	49	2024-01-15	5	39.50	0.09	197.50	179.73	t	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1273	72	46	2024-01-15	9	25.50	0.08	229.50	211.14	t	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1274	14	32	2024-01-15	3	48.00	0.04	144.00	138.24	t	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1275	131	14	2024-01-15	1	12.00	0.01	12.00	11.88	t	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1276	26	32	2024-01-15	9	48.00	0.03	432.00	419.04	t	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1277	92	42	2024-01-15	6	53.00	0.08	318.00	292.56	t	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1278	90	22	2024-01-15	7	54.00	0.01	378.00	374.22	t	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1279	121	28	2024-01-15	7	46.00	0.06	322.00	302.68	t	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1280	137	28	2024-01-15	7	46.00	0.06	322.00	302.68	t	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1281	147	23	2024-01-16	10	24.00	0.01	240.00	237.60	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1282	71	37	2024-01-16	4	88.00	0.02	352.00	344.96	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1283	103	37	2024-01-16	9	88.00	0.02	792.00	776.16	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1284	146	12	2024-01-16	7	44.00	0.04	308.00	295.68	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1285	4	51	2024-01-16	6	31.50	0.02	189.00	185.22	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1286	15	25	2024-01-16	5	65.00	0.03	325.00	315.25	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1287	84	6	2024-01-16	7	25.00	0.09	175.00	159.25	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1288	74	16	2024-01-16	8	26.00	0.07	208.00	193.44	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1289	87	11	2024-01-16	5	32.00	0.02	160.00	156.80	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1290	113	14	2024-01-16	9	12.00	0.08	108.00	99.36	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1291	69	8	2024-01-16	1	40.00	0.08	40.00	36.80	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1292	123	34	2024-01-16	8	9.50	0.07	76.00	70.68	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1293	33	38	2024-01-16	1	39.00	0.05	39.00	37.05	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1294	135	47	2024-01-16	8	82.50	0.07	660.00	613.80	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1295	131	53	2024-01-16	10	22.50	0.07	225.00	209.25	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1296	20	48	2024-01-16	10	44.50	0.01	445.00	440.55	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1297	47	29	2024-01-16	5	40.00	0.02	200.00	196.00	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1298	105	18	2024-01-16	9	43.00	0.07	387.00	359.91	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1299	133	48	2024-01-17	7	44.50	0.09	311.50	283.47	t	2	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1300	45	17	2024-01-17	4	80.00	0.03	320.00	310.40	t	2	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1301	47	19	2024-01-17	9	38.00	0.00	342.00	342.00	f	2	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1302	30	48	2024-01-17	9	44.50	0.02	400.50	392.49	t	2	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1303	18	48	2024-01-17	1	44.50	0.08	44.50	40.94	t	2	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1304	140	34	2024-01-17	3	9.50	0.02	28.50	27.93	t	2	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1305	21	38	2024-01-17	5	39.00	0.08	195.00	179.40	t	2	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1306	69	34	2024-01-17	10	9.50	0.03	95.00	92.15	t	2	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1307	35	13	2024-01-17	5	23.00	0.10	115.00	103.50	t	2	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1308	146	6	2024-01-17	8	25.00	0.00	200.00	200.00	f	2	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1309	8	35	2024-01-17	5	63.00	0.08	315.00	289.80	t	2	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1310	77	27	2024-01-17	6	85.00	0.08	510.00	469.20	t	2	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1311	21	24	2024-01-17	6	11.00	0.05	66.00	62.70	t	2	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1312	34	31	2024-01-17	3	37.00	0.08	111.00	102.12	t	2	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1313	80	14	2024-01-17	1	12.00	0.08	12.00	11.04	t	2	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1314	25	10	2024-01-17	2	15.00	0.04	30.00	28.80	t	2	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1315	53	28	2024-01-18	1	46.00	0.09	46.00	41.86	t	3	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1316	128	16	2024-01-18	10	26.00	0.03	260.00	252.20	t	3	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1317	47	32	2024-01-18	3	48.00	0.04	144.00	138.24	t	3	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1318	10	9	2024-01-18	3	36.00	0.00	108.00	108.00	f	3	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1319	5	18	2024-01-18	9	43.00	0.09	387.00	352.17	t	3	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1320	148	2	2024-01-18	6	50.00	0.10	300.00	270.00	t	3	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1321	100	35	2024-01-18	7	63.00	0.04	441.00	423.36	t	3	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1322	21	3	2024-01-18	2	20.00	0.02	40.00	39.20	t	3	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1323	70	29	2024-01-18	4	40.00	0.07	160.00	148.80	t	3	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1324	71	8	2024-01-18	2	40.00	0.04	80.00	76.80	t	3	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1325	56	36	2024-01-18	10	26.50	0.08	265.00	243.80	t	3	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1326	70	36	2024-01-18	10	26.50	0.03	265.00	257.05	t	3	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1327	16	3	2024-01-18	10	20.00	0.05	200.00	190.00	t	3	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1328	8	29	2024-01-18	8	40.00	0.01	320.00	316.80	t	3	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1329	149	14	2024-01-18	3	12.00	0.07	36.00	33.48	t	3	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1330	42	30	2024-01-19	3	18.00	0.04	54.00	51.84	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1331	34	9	2024-01-19	8	36.00	0.05	288.00	273.60	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1332	117	38	2024-01-19	6	39.00	0.10	234.00	210.60	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1333	1	12	2024-01-19	4	44.00	0.02	176.00	172.48	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1334	35	31	2024-01-19	6	37.00	0.04	222.00	213.12	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1335	76	42	2024-01-19	4	53.00	0.05	212.00	201.40	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1336	27	16	2024-01-19	5	26.00	0.06	130.00	122.20	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1337	119	15	2024-01-19	3	70.00	0.06	210.00	197.40	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1338	128	21	2024-01-19	7	34.00	0.06	238.00	223.72	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1339	74	8	2024-01-19	10	40.00	0.08	400.00	368.00	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1340	21	8	2024-01-19	6	40.00	0.03	240.00	232.80	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1341	119	13	2024-01-19	9	23.00	0.06	207.00	194.58	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1342	11	49	2024-01-19	8	39.50	0.06	316.00	297.04	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1343	118	47	2024-01-19	10	82.50	0.04	825.00	792.00	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1344	131	39	2024-01-19	10	35.00	0.04	350.00	336.00	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1345	86	36	2024-01-19	2	26.50	0.01	53.00	52.47	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1346	63	14	2024-01-19	4	12.00	0.01	48.00	47.52	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1347	120	5	2024-01-19	7	60.00	0.08	420.00	386.40	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1348	108	40	2024-01-19	4	13.00	0.07	52.00	48.36	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1349	22	7	2024-01-19	8	90.00	0.08	720.00	662.40	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1350	102	6	2024-01-19	10	25.00	0.07	250.00	232.50	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1351	80	14	2024-01-19	10	12.00	0.09	120.00	109.20	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1352	111	40	2024-01-19	6	13.00	0.02	78.00	76.44	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1353	76	48	2024-01-19	6	44.50	0.04	267.00	256.32	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1354	88	22	2024-01-20	2	54.00	0.02	108.00	105.84	t	5	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1355	120	33	2024-01-20	6	21.00	0.08	126.00	115.92	t	5	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1356	123	47	2024-01-20	2	82.50	0.10	165.00	148.50	t	5	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1357	7	32	2024-01-20	2	48.00	0.07	96.00	89.28	t	5	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1358	47	48	2024-01-20	1	44.50	0.05	44.50	42.28	t	5	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1359	90	26	2024-01-20	8	22.00	0.01	176.00	174.24	t	5	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1360	122	9	2024-01-20	1	36.00	0.07	36.00	33.48	t	5	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1361	122	38	2024-01-20	8	39.00	0.00	312.00	312.00	f	5	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1362	105	19	2024-01-20	2	38.00	0.08	76.00	69.92	t	5	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1363	24	15	2024-01-20	8	70.00	0.01	560.00	554.40	t	5	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1364	33	41	2024-01-20	6	33.50	0.00	201.00	201.00	f	5	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1365	84	1	2024-01-20	1	30.00	0.09	30.00	27.30	t	5	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1366	88	12	2024-01-20	3	44.00	0.04	132.00	126.72	t	5	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1367	92	44	2024-01-20	9	10.50	0.03	94.50	91.66	t	5	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1368	135	42	2024-01-20	3	53.00	0.07	159.00	147.87	t	5	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1369	122	16	2024-01-21	1	26.00	0.04	26.00	24.96	t	6	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1370	69	3	2024-01-21	1	20.00	0.09	20.00	18.20	t	6	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1371	4	50	2024-01-21	6	17.50	0.04	105.00	100.80	t	6	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1372	74	38	2024-01-21	5	39.00	0.03	195.00	189.15	t	6	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1373	5	18	2024-01-21	10	43.00	0.01	430.00	425.70	t	6	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1374	68	1	2024-01-21	8	30.00	0.05	240.00	228.00	t	6	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1375	66	2	2024-01-21	5	50.00	0.04	250.00	240.00	t	6	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1376	78	31	2024-01-21	2	37.00	0.02	74.00	72.52	t	6	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1377	14	50	2024-01-21	3	17.50	0.00	52.50	52.50	f	6	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1378	27	1	2024-01-21	8	30.00	0.08	240.00	220.80	t	6	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1379	70	21	2024-01-21	2	34.00	0.02	68.00	66.64	t	6	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1380	78	17	2024-01-21	6	80.00	0.03	480.00	465.60	t	6	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1381	85	52	2024-01-21	3	47.50	0.03	142.50	138.23	t	6	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1382	142	52	2024-01-21	9	47.50	0.01	427.50	423.23	t	6	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1383	84	29	2024-01-21	1	40.00	0.00	40.00	40.00	f	6	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1384	142	8	2024-01-21	10	40.00	0.02	400.00	392.00	t	6	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1385	76	31	2024-01-21	4	37.00	0.10	148.00	133.20	t	6	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1386	8	39	2024-01-21	8	35.00	0.03	280.00	271.60	t	6	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1387	136	46	2024-01-22	8	25.50	0.05	204.00	193.80	t	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1388	71	25	2024-01-22	5	65.00	0.01	325.00	321.75	t	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1389	101	40	2024-01-22	2	13.00	0.09	26.00	23.66	t	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1390	65	44	2024-01-22	3	10.50	0.00	31.50	31.50	f	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1391	85	32	2024-01-22	5	48.00	0.00	240.00	240.00	f	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1392	11	25	2024-01-22	2	65.00	0.08	130.00	119.60	t	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1393	42	15	2024-01-22	3	70.00	0.02	210.00	205.80	t	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1394	79	50	2024-01-22	4	17.50	0.06	70.00	65.80	t	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1395	108	38	2024-01-22	2	39.00	0.09	78.00	70.98	t	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1396	40	41	2024-01-22	8	33.50	0.07	268.00	249.24	t	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1397	106	4	2024-01-22	8	10.00	0.06	80.00	75.20	t	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1398	57	43	2024-01-22	5	28.00	0.04	140.00	134.40	t	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1399	116	45	2024-01-22	7	59.50	0.04	416.50	399.84	t	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1400	27	24	2024-01-22	5	11.00	0.01	55.00	54.45	t	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1401	56	19	2024-01-22	7	38.00	0.05	266.00	252.70	t	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1402	69	20	2024-01-22	8	17.00	0.08	136.00	125.12	t	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1403	119	49	2024-01-23	8	39.50	0.05	316.00	300.20	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1404	34	15	2024-01-23	2	70.00	0.04	140.00	134.40	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1405	147	53	2024-01-23	1	22.50	0.04	22.50	21.60	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1406	110	33	2024-01-23	2	21.00	0.05	42.00	39.90	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1407	50	26	2024-01-23	6	22.00	0.01	132.00	130.68	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1408	72	11	2024-01-23	5	32.00	0.07	160.00	148.80	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1409	116	8	2024-01-23	9	40.00	0.09	360.00	327.60	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1410	144	19	2024-01-23	3	38.00	0.01	114.00	112.86	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1411	95	32	2024-01-23	7	48.00	0.07	336.00	312.48	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1412	120	18	2024-01-23	10	43.00	0.00	430.00	430.00	f	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1413	140	28	2024-01-23	6	46.00	0.09	276.00	251.16	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1414	77	14	2024-01-23	4	12.00	0.07	48.00	44.64	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1415	16	32	2024-01-23	7	48.00	0.04	336.00	322.56	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1416	36	28	2024-01-23	9	46.00	0.06	414.00	389.16	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1417	25	32	2024-01-23	6	48.00	0.06	288.00	270.72	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1418	27	27	2024-01-23	10	85.00	0.04	850.00	816.00	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1419	22	12	2024-01-23	7	44.00	0.10	308.00	277.20	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1420	67	39	2024-01-23	5	35.00	0.01	175.00	173.25	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1421	128	37	2024-01-23	5	88.00	0.08	440.00	404.80	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1422	118	18	2024-01-24	7	43.00	0.07	301.00	279.93	t	2	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1423	26	8	2024-01-24	5	40.00	0.04	200.00	192.00	t	2	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1424	64	43	2024-01-24	1	28.00	0.03	28.00	27.16	t	2	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1425	142	15	2024-01-24	7	70.00	0.07	490.00	455.70	t	2	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1426	117	51	2024-01-24	9	31.50	0.04	283.50	272.16	t	2	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1427	135	2	2024-01-24	2	50.00	0.06	100.00	94.00	t	2	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1428	89	30	2024-01-24	2	18.00	0.04	36.00	34.56	t	2	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1429	129	2	2024-01-24	5	50.00	0.08	250.00	230.00	t	2	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1430	42	43	2024-01-24	9	28.00	0.05	252.00	239.40	t	2	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1431	125	37	2024-01-24	2	88.00	0.05	176.00	167.20	t	2	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1432	148	10	2024-01-24	6	15.00	0.07	90.00	83.70	t	2	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1433	38	25	2024-01-24	5	65.00	0.03	325.00	315.25	t	2	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1434	18	2	2024-01-24	3	50.00	0.03	150.00	145.50	t	2	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1435	6	25	2024-01-24	10	65.00	0.03	650.00	630.50	t	2	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1436	144	47	2024-01-24	2	82.50	0.02	165.00	161.70	t	2	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1437	57	3	2024-01-24	1	20.00	0.02	20.00	19.60	t	2	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1438	129	23	2024-01-24	7	24.00	0.04	168.00	161.28	t	2	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1439	35	1	2024-01-24	5	30.00	0.09	150.00	136.50	t	2	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1440	144	48	2024-01-24	1	44.50	0.06	44.50	41.83	t	2	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1441	105	45	2024-01-24	6	59.50	0.06	357.00	335.58	t	2	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1442	39	4	2024-01-24	2	10.00	0.08	20.00	18.40	t	2	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1443	52	41	2024-01-25	1	33.50	0.04	33.50	32.16	t	3	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1444	87	1	2024-01-25	3	30.00	0.02	90.00	88.20	t	3	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1445	131	46	2024-01-25	6	25.50	0.02	153.00	149.94	t	3	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1446	12	6	2024-01-25	3	25.00	0.06	75.00	70.50	t	3	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1447	128	26	2024-01-25	8	22.00	0.10	176.00	158.40	t	3	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1448	77	6	2024-01-25	10	25.00	0.05	250.00	237.50	t	3	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1449	68	12	2024-01-25	10	44.00	0.04	440.00	422.40	t	3	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1450	34	41	2024-01-25	7	33.50	0.02	234.50	229.81	t	3	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1451	96	15	2024-01-25	8	70.00	0.09	560.00	509.60	t	3	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1452	123	31	2024-01-25	9	37.00	0.04	333.00	319.68	t	3	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1453	136	46	2024-01-25	6	25.50	0.04	153.00	146.88	t	3	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1454	104	17	2024-01-25	4	80.00	0.03	320.00	310.40	t	3	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1455	11	50	2024-01-25	5	17.50	0.07	87.50	81.38	t	3	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1456	42	1	2024-01-25	3	30.00	0.05	90.00	85.50	t	3	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1457	5	17	2024-01-25	1	80.00	0.07	80.00	74.40	t	3	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1458	65	16	2024-01-25	2	26.00	0.03	52.00	50.44	t	3	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1459	121	24	2024-01-26	10	11.00	0.07	110.00	102.30	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1460	52	48	2024-01-26	8	44.50	0.02	356.00	348.88	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1461	101	12	2024-01-26	6	44.00	0.02	264.00	258.72	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1462	35	45	2024-01-26	8	59.50	0.09	476.00	433.16	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1463	128	17	2024-01-26	9	80.00	0.07	720.00	669.60	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1464	116	14	2024-01-26	3	12.00	0.07	36.00	33.48	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1465	70	15	2024-01-26	8	70.00	0.02	560.00	548.80	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1466	64	24	2024-01-26	7	11.00	0.01	77.00	76.23	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1467	13	33	2024-01-26	2	21.00	0.04	42.00	40.32	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1468	99	19	2024-01-26	3	38.00	0.04	114.00	109.44	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1469	82	18	2024-01-26	9	43.00	0.02	387.00	379.26	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1470	87	20	2024-01-26	1	17.00	0.03	17.00	16.49	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1471	117	32	2024-01-26	10	48.00	0.08	480.00	441.60	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1472	133	4	2024-01-26	2	10.00	0.00	20.00	20.00	f	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1473	148	6	2024-01-26	9	25.00	0.05	225.00	213.75	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1474	63	8	2024-01-26	5	40.00	0.06	200.00	188.00	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1475	17	24	2024-01-26	4	11.00	0.01	44.00	43.56	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1476	31	42	2024-01-26	9	53.00	0.01	477.00	472.23	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1477	54	43	2024-01-26	7	28.00	0.06	196.00	184.24	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1478	2	42	2024-01-26	1	53.00	0.02	53.00	51.94	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1479	51	33	2024-01-26	8	21.00	0.03	168.00	162.96	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1480	25	10	2024-01-26	2	15.00	0.10	30.00	27.00	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1481	126	8	2024-01-26	10	40.00	0.04	400.00	384.00	t	4	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1482	118	15	2024-01-27	2	70.00	0.00	140.00	140.00	f	5	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1483	40	1	2024-01-27	1	30.00	0.07	30.00	27.90	t	5	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1484	120	7	2024-01-27	9	90.00	0.09	810.00	737.10	t	5	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1485	18	8	2024-01-27	4	40.00	0.02	160.00	156.80	t	5	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1486	12	34	2024-01-27	1	9.50	0.08	9.50	8.74	t	5	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1487	118	29	2024-01-27	3	40.00	0.06	120.00	112.80	t	5	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1488	19	31	2024-01-27	5	37.00	0.03	185.00	179.45	t	5	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1489	19	42	2024-01-27	2	53.00	0.05	106.00	100.70	t	5	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1490	27	38	2024-01-27	3	39.00	0.04	117.00	112.32	t	5	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1491	146	7	2024-01-27	2	90.00	0.10	180.00	162.00	t	5	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1492	95	17	2024-01-27	1	80.00	0.01	80.00	79.20	t	5	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1493	31	43	2024-01-27	9	28.00	0.03	252.00	244.44	t	5	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1494	139	15	2024-01-27	9	70.00	0.06	630.00	592.20	t	5	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1495	46	42	2024-01-27	7	53.00	0.04	371.00	356.16	t	5	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1496	21	24	2024-01-27	1	11.00	0.03	11.00	10.67	t	5	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1497	71	14	2024-01-27	1	12.00	0.10	12.00	10.80	t	5	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1498	15	41	2024-01-27	1	33.50	0.01	33.50	33.17	t	5	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1499	66	8	2024-01-27	2	40.00	0.02	80.00	78.40	t	5	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1500	63	39	2024-01-28	6	35.00	0.09	210.00	191.10	t	6	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1501	103	23	2024-01-28	8	24.00	0.02	192.00	188.16	t	6	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1502	75	22	2024-01-28	7	54.00	0.06	378.00	355.32	t	6	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1503	31	37	2024-01-28	3	88.00	0.04	264.00	253.44	t	6	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1504	35	10	2024-01-28	6	15.00	0.02	90.00	88.20	t	6	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1505	38	2	2024-01-28	7	50.00	0.01	350.00	346.50	t	6	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1506	45	18	2024-01-28	6	43.00	0.05	258.00	245.10	t	6	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1507	37	49	2024-01-28	5	39.50	0.09	197.50	179.73	t	6	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1508	143	22	2024-01-28	1	54.00	0.07	54.00	50.22	t	6	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1509	121	44	2024-01-28	7	10.50	0.01	73.50	72.77	t	6	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1510	14	13	2024-01-28	3	23.00	0.04	69.00	66.24	t	6	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1511	32	36	2024-01-29	5	26.50	0.03	132.50	128.53	t	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1512	33	20	2024-01-29	4	17.00	0.08	68.00	62.56	t	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1513	120	32	2024-01-29	2	48.00	0.07	96.00	89.28	t	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1514	110	52	2024-01-29	6	47.50	0.03	285.00	276.45	t	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1515	6	5	2024-01-29	1	60.00	0.10	60.00	54.00	t	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1516	149	40	2024-01-29	9	13.00	0.07	117.00	108.81	t	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1517	148	47	2024-01-29	4	82.50	0.02	330.00	323.40	t	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1518	70	46	2024-01-29	2	25.50	0.03	51.00	49.47	t	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1519	126	31	2024-01-29	10	37.00	0.04	370.00	355.20	t	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1520	87	40	2024-01-29	9	13.00	0.05	117.00	111.15	t	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1521	110	42	2024-01-29	5	53.00	0.06	265.00	249.10	t	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1522	96	6	2024-01-29	9	25.00	0.04	225.00	216.00	t	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1523	107	48	2024-01-29	8	44.50	0.03	356.00	345.32	t	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1524	49	32	2024-01-29	2	48.00	0.07	96.00	89.28	t	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1525	104	7	2024-01-29	5	90.00	0.06	450.00	423.00	t	0	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1526	139	9	2024-01-30	7	36.00	0.06	252.00	236.88	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1527	40	25	2024-01-30	5	65.00	0.09	325.00	295.75	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1528	122	16	2024-01-30	9	26.00	0.06	234.00	219.96	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1529	51	42	2024-01-30	6	53.00	0.09	318.00	289.38	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1530	141	34	2024-01-30	1	9.50	0.08	9.50	8.74	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1531	144	27	2024-01-30	5	85.00	0.02	425.00	416.50	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1532	87	41	2024-01-30	8	33.50	0.07	268.00	249.24	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1533	18	10	2024-01-30	6	15.00	0.08	90.00	82.80	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1534	114	3	2024-01-30	4	20.00	0.10	80.00	72.00	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1535	52	15	2024-01-30	7	70.00	0.03	490.00	475.30	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1536	65	33	2024-01-30	8	21.00	0.05	168.00	159.60	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1537	146	14	2024-01-30	4	12.00	0.10	48.00	43.20	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1538	109	32	2024-01-30	3	48.00	0.03	144.00	139.68	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1539	111	28	2024-01-30	8	46.00	0.10	368.00	331.20	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1540	49	32	2024-01-30	3	48.00	0.03	144.00	139.68	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1541	47	42	2024-01-30	9	53.00	0.05	477.00	453.15	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1542	93	45	2024-01-30	7	59.50	0.00	416.50	416.50	f	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1543	113	16	2024-01-30	7	26.00	0.06	182.00	171.08	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1544	53	51	2024-01-30	3	31.50	0.01	94.50	93.55	t	1	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1545	101	20	2024-01-31	8	17.00	0.04	136.00	130.56	t	2	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1546	38	19	2024-01-31	9	38.00	0.09	342.00	311.22	t	2	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1547	83	27	2024-01-31	4	85.00	0.05	340.00	323.00	t	2	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1548	109	23	2024-01-31	5	24.00	0.10	120.00	108.00	t	2	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1549	21	26	2024-01-31	4	22.00	0.10	88.00	79.20	t	2	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1550	58	22	2024-01-31	7	54.00	0.00	378.00	378.00	f	2	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1551	116	33	2024-01-31	8	21.00	0.07	168.00	156.24	t	2	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1552	98	30	2024-01-31	8	18.00	0.02	144.00	141.12	t	2	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1553	117	39	2024-01-31	4	35.00	0.08	140.00	128.80	t	2	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1554	115	15	2024-01-31	6	70.00	0.06	420.00	394.80	t	2	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1555	149	41	2024-01-31	5	33.50	0.07	167.50	155.77	t	2	1	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1556	2	51	2024-02-01	5	31.50	0.02	157.50	154.35	t	3	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1557	147	43	2024-02-01	1	28.00	0.09	28.00	25.48	t	3	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1558	111	7	2024-02-01	10	90.00	0.01	900.00	891.00	t	3	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1559	138	35	2024-02-01	4	63.00	0.08	252.00	231.84	t	3	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1560	92	22	2024-02-01	7	54.00	0.01	378.00	374.22	t	3	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1561	122	41	2024-02-01	8	33.50	0.07	268.00	249.24	t	3	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1562	150	26	2024-02-01	2	22.00	0.04	44.00	42.24	t	3	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1563	79	8	2024-02-01	6	40.00	0.00	240.00	240.00	f	3	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1564	68	14	2024-02-01	9	12.00	0.05	108.00	102.60	t	3	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1565	97	33	2024-02-01	1	21.00	0.02	21.00	20.58	t	3	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1566	9	26	2024-02-01	7	22.00	0.03	154.00	149.38	t	3	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1567	26	12	2024-02-01	8	44.00	0.02	352.00	344.96	t	3	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1568	26	26	2024-02-01	6	22.00	0.01	132.00	130.68	t	3	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1569	88	4	2024-02-01	1	10.00	0.10	10.00	9.00	t	3	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1570	26	37	2024-02-01	9	88.00	0.09	792.00	720.72	t	3	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1571	85	49	2024-02-02	7	39.50	0.07	276.50	257.15	t	4	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1572	52	25	2024-02-02	1	65.00	0.07	65.00	60.45	t	4	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1573	129	24	2024-02-02	2	11.00	0.01	22.00	21.78	t	4	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1574	117	14	2024-02-02	2	12.00	0.06	24.00	22.56	t	4	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1575	113	47	2024-02-02	10	82.50	0.09	825.00	750.75	t	4	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1576	39	14	2024-02-02	8	12.00	0.04	96.00	92.16	t	4	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1577	73	7	2024-02-02	1	90.00	0.06	90.00	84.60	t	4	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1578	62	47	2024-02-02	1	82.50	0.07	82.50	76.73	t	4	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1579	82	13	2024-02-02	7	23.00	0.04	161.00	154.56	t	4	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1580	130	29	2024-02-02	10	40.00	0.03	400.00	388.00	t	4	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1581	7	31	2024-02-02	1	37.00	0.06	37.00	34.78	t	4	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1582	115	15	2024-02-02	1	70.00	0.03	70.00	67.90	t	4	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1583	115	31	2024-02-02	3	37.00	0.08	111.00	102.12	t	4	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1584	7	31	2024-02-02	5	37.00	0.03	185.00	179.45	t	4	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1585	60	1	2024-02-02	1	30.00	0.05	30.00	28.50	t	4	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1586	19	23	2024-02-02	1	24.00	0.07	24.00	22.32	t	4	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1587	134	7	2024-02-02	9	90.00	0.09	810.00	737.10	t	4	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1588	58	53	2024-02-02	8	22.50	0.06	180.00	169.20	t	4	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1589	30	47	2024-02-02	3	82.50	0.07	247.50	230.17	t	4	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1590	75	52	2024-02-02	10	47.50	0.08	475.00	437.00	t	4	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1591	81	19	2024-02-02	7	38.00	0.06	266.00	250.04	t	4	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1592	120	21	2024-02-02	6	34.00	0.07	204.00	189.72	t	4	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1593	147	5	2024-02-03	8	60.00	0.04	480.00	460.80	t	5	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1594	112	40	2024-02-03	6	13.00	0.09	78.00	70.98	t	5	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1595	22	1	2024-02-03	4	30.00	0.09	120.00	109.20	t	5	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1596	139	18	2024-02-03	4	43.00	0.10	172.00	154.80	t	5	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1597	25	18	2024-02-03	8	43.00	0.00	344.00	344.00	f	5	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1598	60	12	2024-02-03	5	44.00	0.06	220.00	206.80	t	5	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1599	89	36	2024-02-03	8	26.50	0.04	212.00	203.52	t	5	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1600	76	14	2024-02-03	2	12.00	0.09	24.00	21.84	t	5	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1601	84	47	2024-02-03	6	82.50	0.06	495.00	465.30	t	5	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1602	67	2	2024-02-03	4	50.00	0.08	200.00	184.00	t	5	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1603	141	50	2024-02-03	6	17.50	0.09	105.00	95.55	t	5	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1604	7	51	2024-02-03	1	31.50	0.04	31.50	30.24	t	5	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1605	40	29	2024-02-03	6	40.00	0.02	240.00	235.20	t	5	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1606	149	21	2024-02-03	1	34.00	0.01	34.00	33.66	t	5	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1607	100	28	2024-02-03	6	46.00	0.06	276.00	259.44	t	5	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1608	67	37	2024-02-03	10	88.00	0.04	880.00	844.80	t	5	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1609	70	51	2024-02-03	2	31.50	0.08	63.00	57.96	t	5	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1610	81	50	2024-02-03	3	17.50	0.09	52.50	47.78	t	5	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1611	119	25	2024-02-03	2	65.00	0.01	130.00	128.70	t	5	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1612	73	1	2024-02-03	9	30.00	0.02	270.00	264.60	t	5	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1613	147	14	2024-02-04	7	12.00	0.09	84.00	76.44	t	6	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1614	102	4	2024-02-04	10	10.00	0.06	100.00	94.00	t	6	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1615	147	15	2024-02-04	1	70.00	0.04	70.00	67.20	t	6	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1616	140	6	2024-02-04	2	25.00	0.01	50.00	49.50	t	6	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1617	149	31	2024-02-04	10	37.00	0.01	370.00	366.30	t	6	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1618	49	44	2024-02-04	2	10.50	0.09	21.00	19.11	t	6	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1619	90	25	2024-02-04	3	65.00	0.02	195.00	191.10	t	6	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1620	101	38	2024-02-04	6	39.00	0.07	234.00	217.62	t	6	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1621	113	49	2024-02-04	10	39.50	0.02	395.00	387.10	t	6	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1622	59	21	2024-02-04	9	34.00	0.06	306.00	287.64	t	6	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1623	55	44	2024-02-04	1	10.50	0.03	10.50	10.19	t	6	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1624	43	10	2024-02-04	2	15.00	0.02	30.00	29.40	t	6	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1625	94	28	2024-02-04	4	46.00	0.00	184.00	184.00	f	6	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1626	79	29	2024-02-04	6	40.00	0.03	240.00	232.80	t	6	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1627	80	15	2024-02-04	2	70.00	0.07	140.00	130.20	t	6	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1628	64	39	2024-02-05	8	35.00	0.04	280.00	268.80	t	0	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1629	30	2	2024-02-05	3	50.00	0.08	150.00	138.00	t	0	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1630	58	8	2024-02-05	6	40.00	0.04	240.00	230.40	t	0	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1631	114	22	2024-02-05	9	54.00	0.03	486.00	471.42	t	0	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1632	96	26	2024-02-05	3	22.00	0.04	66.00	63.36	t	0	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1633	2	49	2024-02-05	2	39.50	0.08	79.00	72.68	t	0	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1634	60	40	2024-02-05	6	13.00	0.06	78.00	73.32	t	0	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1635	149	17	2024-02-05	8	80.00	0.05	640.00	608.00	t	0	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1636	42	45	2024-02-05	5	59.50	0.05	297.50	282.63	t	0	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1637	75	27	2024-02-05	10	85.00	0.09	850.00	773.50	t	0	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1638	2	8	2024-02-05	2	40.00	0.06	80.00	75.20	t	0	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1639	103	23	2024-02-05	3	24.00	0.08	72.00	66.24	t	0	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1640	144	5	2024-02-05	8	60.00	0.08	480.00	441.60	t	0	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1641	86	13	2024-02-05	10	23.00	0.08	230.00	211.60	t	0	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1642	136	53	2024-02-05	1	22.50	0.09	22.50	20.48	t	0	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1643	84	51	2024-02-05	6	31.50	0.05	189.00	179.55	t	0	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1644	56	8	2024-02-05	7	40.00	0.05	280.00	266.00	t	0	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1645	82	46	2024-02-05	4	25.50	0.00	102.00	102.00	f	0	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1646	39	1	2024-02-06	8	30.00	0.07	240.00	223.20	t	1	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1647	82	12	2024-02-06	1	44.00	0.00	44.00	44.00	f	1	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1648	110	8	2024-02-06	2	40.00	0.06	80.00	75.20	t	1	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1649	69	11	2024-02-06	1	32.00	0.02	32.00	31.36	t	1	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1650	51	38	2024-02-06	8	39.00	0.08	312.00	287.04	t	1	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1651	150	41	2024-02-06	10	33.50	0.05	335.00	318.25	t	1	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1652	145	20	2024-02-06	8	17.00	0.08	136.00	125.12	t	1	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1653	15	53	2024-02-06	5	22.50	0.06	112.50	105.75	t	1	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1654	100	28	2024-02-06	2	46.00	0.03	92.00	89.24	t	1	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1655	118	32	2024-02-06	9	48.00	0.03	432.00	419.04	t	1	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1656	138	15	2024-02-06	10	70.00	0.04	700.00	672.00	t	1	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1657	45	50	2024-02-06	3	17.50	0.09	52.50	47.78	t	1	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1658	111	29	2024-02-06	2	40.00	0.01	80.00	79.20	t	1	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1659	76	4	2024-02-06	3	10.00	0.04	30.00	28.80	t	1	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1660	127	39	2024-02-06	3	35.00	0.05	105.00	99.75	t	1	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1661	15	33	2024-02-06	3	21.00	0.07	63.00	58.59	t	1	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1662	17	6	2024-02-06	2	25.00	0.07	50.00	46.50	t	1	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1663	59	52	2024-02-06	8	47.50	0.01	380.00	376.20	t	1	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1664	78	5	2024-02-06	7	60.00	0.09	420.00	382.20	t	1	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1665	117	27	2024-02-06	1	85.00	0.07	85.00	79.05	t	1	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1666	98	3	2024-02-07	4	20.00	0.01	80.00	79.20	t	2	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1667	134	31	2024-02-07	6	37.00	0.02	222.00	217.56	t	2	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1668	11	17	2024-02-07	7	80.00	0.09	560.00	509.60	t	2	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1669	19	41	2024-02-07	7	33.50	0.00	234.50	234.50	f	2	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1670	138	50	2024-02-07	6	17.50	0.02	105.00	102.90	t	2	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1671	149	53	2024-02-07	3	22.50	0.03	67.50	65.48	t	2	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1672	33	19	2024-02-07	5	38.00	0.06	190.00	178.60	t	2	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1673	28	25	2024-02-07	6	65.00	0.06	390.00	366.60	t	2	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1674	138	53	2024-02-07	3	22.50	0.06	67.50	63.45	t	2	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1675	69	23	2024-02-07	8	24.00	0.03	192.00	186.24	t	2	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1676	115	46	2024-02-07	8	25.50	0.01	204.00	201.96	t	2	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1677	15	12	2024-02-07	3	44.00	0.06	132.00	124.08	t	2	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1678	97	4	2024-02-07	1	10.00	0.09	10.00	9.10	t	2	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1679	35	23	2024-02-07	9	24.00	0.02	216.00	211.68	t	2	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1680	66	31	2024-02-07	10	37.00	0.00	370.00	370.00	f	2	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1681	105	39	2024-02-07	10	35.00	0.04	350.00	336.00	t	2	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1682	95	25	2024-02-07	1	65.00	0.06	65.00	61.10	t	2	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1683	58	21	2024-02-07	5	34.00	0.06	170.00	159.80	t	2	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1684	121	41	2024-02-07	8	33.50	0.03	268.00	259.96	t	2	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1685	58	38	2024-02-08	6	39.00	0.06	234.00	219.96	t	3	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1686	15	9	2024-02-08	8	36.00	0.01	288.00	285.12	t	3	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1687	107	47	2024-02-08	6	82.50	0.07	495.00	460.35	t	3	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1688	78	7	2024-02-08	8	90.00	0.10	720.00	648.00	t	3	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1689	59	39	2024-02-08	5	35.00	0.10	175.00	157.50	t	3	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1690	113	7	2024-02-08	8	90.00	0.07	720.00	669.60	t	3	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1691	29	31	2024-02-08	5	37.00	0.08	185.00	170.20	t	3	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1692	75	21	2024-02-08	1	34.00	0.00	34.00	34.00	f	3	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1693	70	16	2024-02-08	6	26.00	0.08	156.00	143.52	t	3	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1694	148	40	2024-02-08	2	13.00	0.10	26.00	23.40	t	3	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1695	147	20	2024-02-08	10	17.00	0.01	170.00	168.30	t	3	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1696	3	11	2024-02-08	2	32.00	0.06	64.00	60.16	t	3	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1697	97	19	2024-02-09	3	38.00	0.01	114.00	112.86	t	4	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1698	52	6	2024-02-09	1	25.00	0.07	25.00	23.25	t	4	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1699	58	27	2024-02-09	9	85.00	0.05	765.00	726.75	t	4	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1700	96	13	2024-02-09	3	23.00	0.04	69.00	66.24	t	4	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1701	110	26	2024-02-09	7	22.00	0.09	154.00	140.14	t	4	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1702	47	35	2024-02-09	3	63.00	0.04	189.00	181.44	t	4	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1703	74	2	2024-02-09	8	50.00	0.02	400.00	392.00	t	4	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1704	141	27	2024-02-09	3	85.00	0.01	255.00	252.45	t	4	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1705	26	33	2024-02-09	8	21.00	0.03	168.00	162.96	t	4	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1706	114	5	2024-02-09	2	60.00	0.05	120.00	114.00	t	4	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1707	89	30	2024-02-09	3	18.00	0.09	54.00	49.14	t	4	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1708	102	11	2024-02-09	7	32.00	0.02	224.00	219.52	t	4	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1709	88	32	2024-02-10	3	48.00	0.08	144.00	132.48	t	5	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1710	100	23	2024-02-10	7	24.00	0.02	168.00	164.64	t	5	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1711	8	45	2024-02-10	3	59.50	0.06	178.50	167.79	t	5	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1712	43	33	2024-02-10	1	21.00	0.02	21.00	20.58	t	5	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1713	4	39	2024-02-10	9	35.00	0.01	315.00	311.85	t	5	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1714	101	47	2024-02-10	1	82.50	0.01	82.50	81.68	t	5	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1715	58	4	2024-02-10	3	10.00	0.06	30.00	28.20	t	5	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1716	40	41	2024-02-10	2	33.50	0.06	67.00	62.98	t	5	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1717	110	9	2024-02-10	5	36.00	0.02	180.00	176.40	t	5	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1718	122	39	2024-02-10	10	35.00	0.09	350.00	318.50	t	5	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1719	137	31	2024-02-10	5	37.00	0.04	185.00	177.60	t	5	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1720	86	29	2024-02-10	4	40.00	0.01	160.00	158.40	t	5	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1721	53	4	2024-02-10	10	10.00	0.10	100.00	90.00	t	5	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1722	64	40	2024-02-10	9	13.00	0.06	117.00	109.98	t	5	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1723	79	15	2024-02-10	9	70.00	0.01	630.00	623.70	t	5	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1724	85	17	2024-02-10	1	80.00	0.09	80.00	72.80	t	5	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1725	122	45	2024-02-10	5	59.50	0.06	297.50	279.65	t	5	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1726	40	24	2024-02-10	2	11.00	0.09	22.00	20.02	t	5	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1727	38	36	2024-02-11	7	26.50	0.05	185.50	176.23	t	6	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1728	9	43	2024-02-11	6	28.00	0.02	168.00	164.64	t	6	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1729	124	36	2024-02-11	10	26.50	0.03	265.00	257.05	t	6	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1730	46	40	2024-02-11	6	13.00	0.04	78.00	74.88	t	6	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1731	1	20	2024-02-11	6	17.00	0.03	102.00	98.94	t	6	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1732	57	20	2024-02-11	7	17.00	0.07	119.00	110.67	t	6	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1733	63	51	2024-02-11	7	31.50	0.07	220.50	205.07	t	6	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1734	29	30	2024-02-11	8	18.00	0.06	144.00	135.36	t	6	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1735	12	41	2024-02-11	1	33.50	0.08	33.50	30.82	t	6	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1736	75	49	2024-02-11	7	39.50	0.01	276.50	273.74	t	6	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1737	76	8	2024-02-11	4	40.00	0.03	160.00	155.20	t	6	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1738	93	2	2024-02-11	6	50.00	0.08	300.00	276.00	t	6	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1739	80	1	2024-02-11	7	30.00	0.06	210.00	197.40	t	6	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1740	137	49	2024-02-11	5	39.50	0.01	197.50	195.53	t	6	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1741	81	42	2024-02-11	2	53.00	0.02	106.00	103.88	t	6	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1742	103	41	2024-02-11	2	33.50	0.06	67.00	62.98	t	6	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1743	43	44	2024-02-11	9	10.50	0.06	94.50	88.83	t	6	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1744	114	38	2024-02-12	9	39.00	0.05	351.00	333.45	t	0	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1745	31	25	2024-02-12	4	65.00	0.03	260.00	252.20	t	0	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1746	28	38	2024-02-12	4	39.00	0.10	156.00	140.40	t	0	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1747	14	51	2024-02-12	4	31.50	0.01	126.00	124.74	t	0	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1748	91	40	2024-02-12	1	13.00	0.02	13.00	12.74	t	0	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1749	129	18	2024-02-12	9	43.00	0.05	387.00	367.65	t	0	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1750	52	23	2024-02-12	7	24.00	0.03	168.00	162.96	t	0	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1751	51	50	2024-02-12	2	17.50	0.07	35.00	32.55	t	0	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1752	135	46	2024-02-12	1	25.50	0.06	25.50	23.97	t	0	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1753	150	5	2024-02-12	4	60.00	0.01	240.00	237.60	t	0	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1754	53	38	2024-02-12	4	39.00	0.03	156.00	151.32	t	0	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1755	15	53	2024-02-12	2	22.50	0.09	45.00	40.95	t	0	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1756	7	12	2024-02-12	8	44.00	0.06	352.00	330.88	t	0	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1757	9	26	2024-02-12	3	22.00	0.03	66.00	64.02	t	0	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1758	136	41	2024-02-12	1	33.50	0.06	33.50	31.49	t	0	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1759	148	10	2024-02-12	6	15.00	0.05	90.00	85.50	t	0	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1760	14	6	2024-02-12	8	25.00	0.05	200.00	190.00	t	0	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1761	112	38	2024-02-12	5	39.00	0.01	195.00	193.05	t	0	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1762	1	49	2024-02-12	9	39.50	0.04	355.50	341.28	t	0	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1763	60	48	2024-02-12	1	44.50	0.03	44.50	43.17	t	0	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1764	112	38	2024-02-12	6	39.00	0.04	234.00	224.64	t	0	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1765	149	50	2024-02-12	10	17.50	0.08	175.00	161.00	t	0	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1766	44	21	2024-02-12	10	34.00	0.07	340.00	316.20	t	0	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1767	148	35	2024-02-13	8	63.00	0.06	504.00	473.76	t	1	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1768	37	39	2024-02-13	3	35.00	0.07	105.00	97.65	t	1	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1769	92	43	2024-02-13	5	28.00	0.09	140.00	127.40	t	1	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1770	48	23	2024-02-13	4	24.00	0.08	96.00	88.32	t	1	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1771	19	41	2024-02-13	1	33.50	0.08	33.50	30.82	t	1	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1772	109	6	2024-02-13	5	25.00	0.06	125.00	117.50	t	1	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1773	63	42	2024-02-13	2	53.00	0.03	106.00	102.82	t	1	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1774	7	34	2024-02-13	1	9.50	0.09	9.50	8.65	t	1	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1775	143	47	2024-02-13	7	82.50	0.08	577.50	531.30	t	1	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1776	138	16	2024-02-13	4	26.00	0.04	104.00	99.84	t	1	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1777	16	26	2024-02-13	9	22.00	0.00	198.00	198.00	f	1	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1778	61	8	2024-02-13	4	40.00	0.06	160.00	150.40	t	1	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1779	150	4	2024-02-13	6	10.00	0.02	60.00	58.80	t	1	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1780	3	8	2024-02-13	10	40.00	0.10	400.00	360.00	t	1	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1781	74	26	2024-02-13	5	22.00	0.05	110.00	104.50	t	1	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1782	145	29	2024-02-14	9	40.00	0.03	360.00	349.20	t	2	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1783	129	44	2024-02-14	2	10.50	0.02	21.00	20.58	t	2	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1784	102	5	2024-02-14	2	60.00	0.01	120.00	118.80	t	2	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1785	148	7	2024-02-14	1	90.00	0.08	90.00	82.80	t	2	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1786	145	49	2024-02-14	8	39.50	0.04	316.00	303.36	t	2	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1787	99	37	2024-02-14	3	88.00	0.02	264.00	258.72	t	2	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1788	115	44	2024-02-14	7	10.50	0.10	73.50	66.15	t	2	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1789	43	27	2024-02-14	4	85.00	0.03	340.00	329.80	t	2	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1790	34	51	2024-02-14	2	31.50	0.08	63.00	57.96	t	2	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1791	5	45	2024-02-14	1	59.50	0.10	59.50	53.55	t	2	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1792	22	33	2024-02-14	8	21.00	0.09	168.00	152.88	t	2	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1793	9	48	2024-02-14	1	44.50	0.01	44.50	44.06	t	2	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1794	16	17	2024-02-14	10	80.00	0.03	800.00	776.00	t	2	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1795	22	52	2024-02-14	9	47.50	0.06	427.50	401.85	t	2	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1796	60	51	2024-02-15	10	31.50	0.03	315.00	305.55	t	3	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1797	142	9	2024-02-15	9	36.00	0.02	324.00	317.52	t	3	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1798	51	21	2024-02-15	7	34.00	0.03	238.00	230.86	t	3	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1799	132	11	2024-02-15	7	32.00	0.03	224.00	217.28	t	3	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1800	46	53	2024-02-15	6	22.50	0.04	135.00	129.60	t	3	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1801	60	40	2024-02-15	4	13.00	0.01	52.00	51.48	t	3	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1802	1	33	2024-02-15	10	21.00	0.07	210.00	195.30	t	3	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1803	53	20	2024-02-15	9	17.00	0.05	153.00	145.35	t	3	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1804	35	25	2024-02-15	7	65.00	0.07	455.00	423.15	t	3	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1805	62	44	2024-02-15	5	10.50	0.09	52.50	47.78	t	3	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1806	22	22	2024-02-15	9	54.00	0.05	486.00	461.70	t	3	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1807	15	46	2024-02-15	6	25.50	0.06	153.00	143.82	t	3	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1808	22	44	2024-02-15	4	10.50	0.04	42.00	40.32	t	3	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1809	76	33	2024-02-15	10	21.00	0.09	210.00	191.10	t	3	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1810	19	3	2024-02-15	5	20.00	0.04	100.00	96.00	t	3	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1811	73	26	2024-02-15	7	22.00	0.08	154.00	141.68	t	3	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1812	30	7	2024-02-15	1	90.00	0.04	90.00	86.40	t	3	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1813	6	12	2024-02-15	9	44.00	0.05	396.00	376.20	t	3	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1814	101	34	2024-02-16	9	9.50	0.05	85.50	81.23	t	4	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1815	82	35	2024-02-16	4	63.00	0.10	252.00	226.80	t	4	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1816	10	37	2024-02-16	7	88.00	0.07	616.00	572.88	t	4	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1817	47	50	2024-02-16	4	17.50	0.09	70.00	63.70	t	4	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1818	3	7	2024-02-16	9	90.00	0.02	810.00	793.80	t	4	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1819	150	49	2024-02-16	1	39.50	0.02	39.50	38.71	t	4	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1820	1	14	2024-02-16	9	12.00	0.10	108.00	97.20	t	4	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1821	42	41	2024-02-16	7	33.50	0.03	234.50	227.47	t	4	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1822	108	49	2024-02-16	1	39.50	0.04	39.50	37.92	t	4	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1823	8	52	2024-02-16	1	47.50	0.01	47.50	47.03	t	4	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1824	9	49	2024-02-16	7	39.50	0.05	276.50	262.68	t	4	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1825	24	3	2024-02-16	2	20.00	0.06	40.00	37.60	t	4	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1826	97	39	2024-02-16	7	35.00	0.04	245.00	235.20	t	4	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1827	143	4	2024-02-16	5	10.00	0.07	50.00	46.50	t	4	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1828	103	20	2024-02-16	2	17.00	0.05	34.00	32.30	t	4	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1829	28	6	2024-02-16	7	25.00	0.06	175.00	164.50	t	4	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1830	125	3	2024-02-17	4	20.00	0.07	80.00	74.40	t	5	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1831	54	39	2024-02-17	8	35.00	0.02	280.00	274.40	t	5	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1832	62	16	2024-02-17	8	26.00	0.05	208.00	197.60	t	5	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1833	43	40	2024-02-17	8	13.00	0.02	104.00	101.92	t	5	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1834	62	23	2024-02-17	5	24.00	0.05	120.00	114.00	t	5	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1835	66	19	2024-02-17	4	38.00	0.07	152.00	141.36	t	5	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1836	63	29	2024-02-17	5	40.00	0.03	200.00	194.00	t	5	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1837	94	30	2024-02-17	10	18.00	0.00	180.00	180.00	f	5	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1838	145	40	2024-02-17	9	13.00	0.00	117.00	117.00	f	5	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1839	78	22	2024-02-17	8	54.00	0.01	432.00	427.68	t	5	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1840	18	48	2024-02-17	8	44.50	0.09	356.00	323.96	t	5	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1841	30	9	2024-02-17	7	36.00	0.09	252.00	229.32	t	5	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1842	118	42	2024-02-17	10	53.00	0.04	530.00	508.80	t	5	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1843	20	40	2024-02-17	5	13.00	0.08	65.00	59.80	t	5	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1844	49	12	2024-02-17	10	44.00	0.04	440.00	422.40	t	5	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1845	52	36	2024-02-17	3	26.50	0.08	79.50	73.14	t	5	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1846	133	14	2024-02-18	10	12.00	0.04	120.00	115.20	t	6	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1847	58	19	2024-02-18	10	38.00	0.03	380.00	368.60	t	6	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1848	131	8	2024-02-18	9	40.00	0.04	360.00	345.60	t	6	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1849	16	43	2024-02-18	4	28.00	0.01	112.00	110.88	t	6	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1850	120	14	2024-02-18	6	12.00	0.01	72.00	71.28	t	6	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1851	97	28	2024-02-18	7	46.00	0.06	322.00	302.68	t	6	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1852	23	46	2024-02-18	10	25.50	0.03	255.00	247.35	t	6	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1853	17	34	2024-02-18	5	9.50	0.02	47.50	46.55	t	6	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1854	26	19	2024-02-18	8	38.00	0.08	304.00	279.68	t	6	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1855	79	48	2024-02-18	7	44.50	0.08	311.50	286.58	t	6	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1856	31	2	2024-02-18	6	50.00	0.01	300.00	297.00	t	6	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1857	8	46	2024-02-18	3	25.50	0.05	76.50	72.68	t	6	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1858	70	15	2024-02-18	4	70.00	0.08	280.00	257.60	t	6	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1859	18	31	2024-02-18	5	37.00	0.01	185.00	183.15	t	6	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1860	20	43	2024-02-18	9	28.00	0.05	252.00	239.40	t	6	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1861	76	45	2024-02-18	7	59.50	0.08	416.50	383.18	t	6	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1862	96	15	2024-02-18	4	70.00	0.06	280.00	263.20	t	6	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1863	18	52	2024-02-18	1	47.50	0.01	47.50	47.03	t	6	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1864	149	53	2024-02-18	7	22.50	0.07	157.50	146.48	t	6	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1865	32	6	2024-02-19	2	25.00	0.02	50.00	49.00	t	0	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1866	58	45	2024-02-19	5	59.50	0.09	297.50	270.73	t	0	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1867	53	28	2024-02-19	2	46.00	0.05	92.00	87.40	t	0	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1868	68	1	2024-02-19	3	30.00	0.03	90.00	87.30	t	0	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1869	126	8	2024-02-19	4	40.00	0.01	160.00	158.40	t	0	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1870	80	4	2024-02-19	8	10.00	0.02	80.00	78.40	t	0	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1871	146	51	2024-02-19	6	31.50	0.04	189.00	181.44	t	0	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1872	80	47	2024-02-19	3	82.50	0.01	247.50	245.03	t	0	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1873	95	25	2024-02-19	1	65.00	0.07	65.00	60.45	t	0	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1874	95	50	2024-02-19	7	17.50	0.02	122.50	120.05	t	0	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1875	109	9	2024-02-19	4	36.00	0.09	144.00	131.04	t	0	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1876	85	22	2024-02-19	6	54.00	0.03	324.00	314.28	t	0	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1877	13	12	2024-02-19	5	44.00	0.05	220.00	209.00	t	0	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1878	72	39	2024-02-19	1	35.00	0.03	35.00	33.95	t	0	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1879	112	13	2024-02-19	6	23.00	0.09	138.00	125.58	t	0	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1880	51	15	2024-02-19	4	70.00	0.05	280.00	266.00	t	0	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1881	150	13	2024-02-19	2	23.00	0.01	46.00	45.54	t	0	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1882	118	31	2024-02-19	9	37.00	0.00	333.00	333.00	f	0	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1883	46	17	2024-02-19	7	80.00	0.09	560.00	509.60	t	0	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1884	51	40	2024-02-20	10	13.00	0.05	130.00	123.50	t	1	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1885	97	9	2024-02-20	9	36.00	0.02	324.00	317.52	t	1	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1886	2	23	2024-02-20	4	24.00	0.02	96.00	94.08	t	1	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1887	48	46	2024-02-20	4	25.50	0.03	102.00	98.94	t	1	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1888	90	2	2024-02-20	4	50.00	0.07	200.00	186.00	t	1	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1889	7	28	2024-02-20	7	46.00	0.00	322.00	322.00	f	1	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1890	126	10	2024-02-20	4	15.00	0.08	60.00	55.20	t	1	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1891	30	3	2024-02-20	5	20.00	0.08	100.00	92.00	t	1	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1892	100	25	2024-02-20	5	65.00	0.06	325.00	305.50	t	1	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1893	137	25	2024-02-20	2	65.00	0.07	130.00	120.90	t	1	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1894	63	4	2024-02-20	10	10.00	0.05	100.00	95.00	t	1	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1895	144	30	2024-02-20	10	18.00	0.01	180.00	178.20	t	1	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1896	43	4	2024-02-20	1	10.00	0.09	10.00	9.10	t	1	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1897	84	24	2024-02-20	4	11.00	0.00	44.00	44.00	f	1	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1898	93	29	2024-02-20	7	40.00	0.06	280.00	263.20	t	1	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1899	89	40	2024-02-21	5	13.00	0.06	65.00	61.10	t	2	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1900	43	38	2024-02-21	9	39.00	0.02	351.00	343.98	t	2	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1901	9	49	2024-02-21	3	39.50	0.08	118.50	109.02	t	2	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1902	133	40	2024-02-21	10	13.00	0.05	130.00	123.50	t	2	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1903	34	7	2024-02-21	10	90.00	0.07	900.00	837.00	t	2	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1904	90	46	2024-02-21	10	25.50	0.00	255.00	255.00	f	2	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1905	126	19	2024-02-21	8	38.00	0.05	304.00	288.80	t	2	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1906	94	28	2024-02-21	6	46.00	0.06	276.00	259.44	t	2	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1907	56	17	2024-02-21	8	80.00	0.03	640.00	620.80	t	2	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1908	57	7	2024-02-21	6	90.00	0.08	540.00	496.80	t	2	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1909	37	53	2024-02-21	6	22.50	0.09	135.00	122.85	t	2	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1910	130	21	2024-02-21	5	34.00	0.02	170.00	166.60	t	2	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1911	86	1	2024-02-21	4	30.00	0.07	120.00	111.60	t	2	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1912	68	39	2024-02-21	1	35.00	0.03	35.00	33.95	t	2	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1913	14	29	2024-02-21	4	40.00	0.07	160.00	148.80	t	2	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1914	107	42	2024-02-21	3	53.00	0.05	159.00	151.05	t	2	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1915	66	20	2024-02-22	7	17.00	0.09	119.00	108.29	t	3	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1916	57	6	2024-02-22	4	25.00	0.03	100.00	97.00	t	3	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1917	135	19	2024-02-22	5	38.00	0.05	190.00	180.50	t	3	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1918	37	25	2024-02-22	4	65.00	0.10	260.00	234.00	t	3	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1919	59	51	2024-02-22	3	31.50	0.06	94.50	88.83	t	3	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1920	35	21	2024-02-22	4	34.00	0.08	136.00	125.12	t	3	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1921	144	6	2024-02-22	6	25.00	0.06	150.00	141.00	t	3	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1922	51	30	2024-02-22	3	18.00	0.04	54.00	51.84	t	3	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1923	7	19	2024-02-22	9	38.00	0.09	342.00	311.22	t	3	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1924	141	49	2024-02-22	1	39.50	0.03	39.50	38.32	t	3	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1925	73	7	2024-02-22	10	90.00	0.08	900.00	828.00	t	3	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1926	123	40	2024-02-22	6	13.00	0.02	78.00	76.44	t	3	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1927	5	15	2024-02-22	3	70.00	0.05	210.00	199.50	t	3	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1928	73	45	2024-02-22	4	59.50	0.04	238.00	228.48	t	3	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1929	91	32	2024-02-22	2	48.00	0.09	96.00	87.36	t	3	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1930	20	42	2024-02-22	7	53.00	0.02	371.00	363.58	t	3	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1931	125	29	2024-02-22	9	40.00	0.10	360.00	324.00	t	3	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1932	33	28	2024-02-22	6	46.00	0.00	276.00	276.00	f	3	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1933	43	13	2024-02-22	5	23.00	0.05	115.00	109.25	t	3	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1934	39	13	2024-02-23	10	23.00	0.07	230.00	213.90	t	4	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1935	139	26	2024-02-23	6	22.00	0.01	132.00	130.68	t	4	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1936	16	43	2024-02-23	6	28.00	0.07	168.00	156.24	t	4	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1937	122	23	2024-02-23	7	24.00	0.07	168.00	156.24	t	4	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1938	128	4	2024-02-23	10	10.00	0.02	100.00	98.00	t	4	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1939	16	4	2024-02-23	5	10.00	0.06	50.00	47.00	t	4	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1940	68	15	2024-02-23	8	70.00	0.08	560.00	515.20	t	4	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1941	26	30	2024-02-23	5	18.00	0.03	90.00	87.30	t	4	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1942	66	15	2024-02-23	8	70.00	0.00	560.00	560.00	f	4	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1943	99	31	2024-02-23	2	37.00	0.06	74.00	69.56	t	4	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1944	22	39	2024-02-23	5	35.00	0.04	175.00	168.00	t	4	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1945	127	36	2024-02-23	1	26.50	0.09	26.50	24.12	t	4	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1946	116	49	2024-02-23	9	39.50	0.07	355.50	330.61	t	4	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1947	87	3	2024-02-23	1	20.00	0.01	20.00	19.80	t	4	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1948	124	27	2024-02-23	8	85.00	0.04	680.00	652.80	t	4	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1949	21	9	2024-02-23	8	36.00	0.08	288.00	264.96	t	4	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1950	11	52	2024-02-23	5	47.50	0.03	237.50	230.38	t	4	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1951	150	41	2024-02-23	8	33.50	0.09	268.00	243.88	t	4	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1952	31	51	2024-02-23	10	31.50	0.02	315.00	308.70	t	4	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1953	139	12	2024-02-23	2	44.00	0.01	88.00	87.12	t	4	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1954	61	18	2024-02-23	7	43.00	0.07	301.00	279.93	t	4	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1955	120	37	2024-02-23	9	88.00	0.08	792.00	728.64	t	4	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1956	129	11	2024-02-23	6	32.00	0.02	192.00	188.16	t	4	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1957	105	8	2024-02-23	7	40.00	0.05	280.00	266.00	t	4	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1958	105	14	2024-02-24	7	12.00	0.00	84.00	84.00	f	5	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1959	42	15	2024-02-24	4	70.00	0.04	280.00	268.80	t	5	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1960	57	13	2024-02-24	8	23.00	0.04	184.00	176.64	t	5	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1961	118	2	2024-02-24	2	50.00	0.08	100.00	92.00	t	5	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1962	148	11	2024-02-24	6	32.00	0.05	192.00	182.40	t	5	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1963	127	30	2024-02-24	8	18.00	0.01	144.00	142.56	t	5	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1964	141	25	2024-02-24	2	65.00	0.03	130.00	126.10	t	5	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1965	82	18	2024-02-24	2	43.00	0.03	86.00	83.42	t	5	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1966	44	50	2024-02-24	8	17.50	0.07	140.00	130.20	t	5	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1967	102	23	2024-02-24	3	24.00	0.04	72.00	69.12	t	5	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1968	128	25	2024-02-24	4	65.00	0.05	260.00	247.00	t	5	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1969	138	42	2024-02-24	1	53.00	0.01	53.00	52.47	t	5	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1970	59	31	2024-02-24	8	37.00	0.09	296.00	269.36	t	5	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1971	132	8	2024-02-24	5	40.00	0.00	200.00	200.00	f	5	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1972	55	35	2024-02-24	5	63.00	0.06	315.00	296.10	t	5	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1973	5	46	2024-02-24	7	25.50	0.07	178.50	166.01	t	5	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1974	128	5	2024-02-24	6	60.00	0.02	360.00	352.80	t	5	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1975	31	25	2024-02-24	7	65.00	0.10	455.00	409.50	t	5	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1976	73	47	2024-02-24	5	82.50	0.02	412.50	404.25	t	5	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1977	136	13	2024-02-24	2	23.00	0.03	46.00	44.62	t	5	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1978	145	43	2024-02-24	5	28.00	0.05	140.00	133.00	t	5	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1979	10	13	2024-02-24	1	23.00	0.02	23.00	22.54	t	5	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1980	68	18	2024-02-24	3	43.00	0.01	129.00	127.71	t	5	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1981	60	20	2024-02-25	4	17.00	0.09	68.00	61.88	t	6	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1982	34	40	2024-02-25	4	13.00	0.04	52.00	49.92	t	6	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1983	37	4	2024-02-25	3	10.00	0.07	30.00	27.90	t	6	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1984	35	23	2024-02-25	10	24.00	0.03	240.00	232.80	t	6	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1985	117	37	2024-02-25	9	88.00	0.10	792.00	712.80	t	6	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1986	45	27	2024-02-25	10	85.00	0.07	850.00	790.50	t	6	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1987	72	6	2024-02-25	1	25.00	0.06	25.00	23.50	t	6	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1988	43	22	2024-02-25	4	54.00	0.00	216.00	216.00	f	6	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1989	104	40	2024-02-25	9	13.00	0.10	117.00	105.30	t	6	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1990	67	32	2024-02-25	8	48.00	0.02	384.00	376.32	t	6	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1991	96	22	2024-02-25	5	54.00	0.08	270.00	248.40	t	6	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1992	78	5	2024-02-25	3	60.00	0.08	180.00	165.60	t	6	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1993	73	2	2024-02-25	8	50.00	0.03	400.00	388.00	t	6	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1994	45	49	2024-02-26	3	39.50	0.04	118.50	113.76	t	0	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1995	30	3	2024-02-26	6	20.00	0.05	120.00	114.00	t	0	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1996	81	27	2024-02-26	10	85.00	0.04	850.00	816.00	t	0	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1997	132	28	2024-02-26	7	46.00	0.00	322.00	322.00	f	0	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1998	94	41	2024-02-26	6	33.50	0.04	201.00	192.96	t	0	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
1999	64	26	2024-02-26	10	22.00	0.01	220.00	217.80	t	0	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2000	125	38	2024-02-26	8	39.00	0.07	312.00	290.16	t	0	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2001	58	8	2024-02-26	4	40.00	0.04	160.00	153.60	t	0	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2002	52	42	2024-02-26	1	53.00	0.10	53.00	47.70	t	0	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2003	29	9	2024-02-26	4	36.00	0.03	144.00	139.68	t	0	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2004	99	13	2024-02-26	10	23.00	0.01	230.00	227.70	t	0	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2005	125	5	2024-02-26	9	60.00	0.05	540.00	513.00	t	0	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2006	149	40	2024-02-26	4	13.00	0.07	52.00	48.36	t	0	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2007	124	49	2024-02-26	5	39.50	0.08	197.50	181.70	t	0	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2008	22	37	2024-02-26	2	88.00	0.05	176.00	167.20	t	0	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2009	145	18	2024-02-26	2	43.00	0.08	86.00	79.12	t	0	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2010	74	53	2024-02-26	8	22.50	0.07	180.00	167.40	t	0	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2011	105	46	2024-02-26	3	25.50	0.01	76.50	75.74	t	0	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2012	77	36	2024-02-27	10	26.50	0.08	265.00	243.80	t	1	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2013	21	48	2024-02-27	6	44.50	0.06	267.00	250.98	t	1	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2014	140	45	2024-02-27	4	59.50	0.00	238.00	238.00	f	1	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2015	16	28	2024-02-27	9	46.00	0.02	414.00	405.72	t	1	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2016	118	25	2024-02-27	5	65.00	0.04	325.00	312.00	t	1	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2017	58	17	2024-02-27	7	80.00	0.01	560.00	554.40	t	1	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2018	133	11	2024-02-27	9	32.00	0.08	288.00	264.96	t	1	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2019	112	3	2024-02-27	7	20.00	0.08	140.00	128.80	t	1	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2020	57	42	2024-02-27	6	53.00	0.05	318.00	302.10	t	1	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2021	116	7	2024-02-27	9	90.00	0.10	810.00	729.00	t	1	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2022	77	44	2024-02-27	8	10.50	0.08	84.00	77.28	t	1	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2023	17	31	2024-02-27	9	37.00	0.03	333.00	323.01	t	1	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2024	37	24	2024-02-27	3	11.00	0.01	33.00	32.67	t	1	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2025	37	40	2024-02-27	8	13.00	0.08	104.00	95.68	t	1	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2026	58	22	2024-02-27	10	54.00	0.03	540.00	523.80	t	1	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2027	51	46	2024-02-27	3	25.50	0.05	76.50	72.68	t	1	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2028	46	6	2024-02-27	2	25.00	0.08	50.00	46.00	t	1	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2029	2	6	2024-02-27	7	25.00	0.02	175.00	171.50	t	1	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2030	90	4	2024-02-27	7	10.00	0.07	70.00	65.10	t	1	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2031	35	3	2024-02-28	5	20.00	0.04	100.00	96.00	t	2	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2032	31	12	2024-02-28	5	44.00	0.07	220.00	204.60	t	2	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2033	14	36	2024-02-28	5	26.50	0.09	132.50	120.58	t	2	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2034	6	40	2024-02-28	9	13.00	0.00	117.00	117.00	f	2	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2035	122	11	2024-02-28	8	32.00	0.01	256.00	253.44	t	2	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2036	77	35	2024-02-28	6	63.00	0.03	378.00	366.66	t	2	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2037	138	32	2024-02-28	3	48.00	0.08	144.00	132.48	t	2	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2038	79	39	2024-02-28	10	35.00	0.02	350.00	343.00	t	2	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2039	143	51	2024-02-28	8	31.50	0.04	252.00	241.92	t	2	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2040	76	1	2024-02-28	1	30.00	0.04	30.00	28.80	t	2	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2041	97	14	2024-02-29	2	12.00	0.02	24.00	23.52	t	3	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2042	85	25	2024-02-29	5	65.00	0.06	325.00	305.50	t	3	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2043	98	22	2024-02-29	4	54.00	0.09	216.00	196.56	t	3	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2044	144	32	2024-02-29	3	48.00	0.05	144.00	136.80	t	3	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2045	8	50	2024-02-29	2	17.50	0.07	35.00	32.55	t	3	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2046	52	38	2024-02-29	7	39.00	0.07	273.00	253.89	t	3	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2047	140	34	2024-02-29	5	9.50	0.00	47.50	47.50	f	3	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2048	69	25	2024-02-29	2	65.00	0.07	130.00	120.90	t	3	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2049	97	16	2024-02-29	2	26.00	0.05	52.00	49.40	t	3	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2050	66	48	2024-02-29	7	44.50	0.04	311.50	299.04	t	3	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2051	41	37	2024-02-29	9	88.00	0.00	792.00	792.00	f	3	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2052	2	10	2024-02-29	2	15.00	0.06	30.00	28.20	t	3	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2053	86	40	2024-02-29	10	13.00	0.07	130.00	120.90	t	3	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2054	104	20	2024-02-29	5	17.00	0.05	85.00	80.75	t	3	2	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2055	71	46	2024-03-01	2	25.50	0.08	51.00	46.92	t	4	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2056	130	44	2024-03-01	1	10.50	0.07	10.50	9.76	t	4	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2057	83	29	2024-03-01	6	40.00	0.09	240.00	218.40	t	4	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2058	93	21	2024-03-01	5	34.00	0.05	170.00	161.50	t	4	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2059	28	19	2024-03-01	6	38.00	0.08	228.00	209.76	t	4	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2060	16	15	2024-03-01	3	70.00	0.08	210.00	193.20	t	4	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2061	93	33	2024-03-01	1	21.00	0.02	21.00	20.58	t	4	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2062	45	40	2024-03-01	5	13.00	0.08	65.00	59.80	t	4	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2063	116	32	2024-03-01	4	48.00	0.05	192.00	182.40	t	4	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2064	126	13	2024-03-01	9	23.00	0.05	207.00	196.65	t	4	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2065	17	48	2024-03-01	2	44.50	0.08	89.00	81.88	t	4	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2066	67	20	2024-03-01	9	17.00	0.02	153.00	149.94	t	4	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2067	19	38	2024-03-01	10	39.00	0.03	390.00	378.30	t	4	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2068	59	25	2024-03-01	10	65.00	0.06	650.00	611.00	t	4	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2069	26	43	2024-03-02	10	28.00	0.09	280.00	254.80	t	5	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2070	66	49	2024-03-02	9	39.50	0.07	355.50	330.61	t	5	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2071	13	52	2024-03-02	8	47.50	0.01	380.00	376.20	t	5	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2072	57	13	2024-03-02	10	23.00	0.01	230.00	227.70	t	5	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2073	78	9	2024-03-02	6	36.00	0.06	216.00	203.04	t	5	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2074	141	33	2024-03-02	4	21.00	0.01	84.00	83.16	t	5	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2075	148	31	2024-03-02	6	37.00	0.02	222.00	217.56	t	5	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2076	27	35	2024-03-02	5	63.00	0.08	315.00	289.80	t	5	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2077	16	10	2024-03-02	9	15.00	0.07	135.00	125.55	t	5	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2078	109	13	2024-03-02	1	23.00	0.09	23.00	20.93	t	5	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2079	115	4	2024-03-02	6	10.00	0.06	60.00	56.40	t	5	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2080	75	36	2024-03-02	6	26.50	0.10	159.00	143.10	t	5	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2081	146	49	2024-03-02	7	39.50	0.09	276.50	251.62	t	5	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2082	91	53	2024-03-02	1	22.50	0.07	22.50	20.92	t	5	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2083	72	51	2024-03-03	5	31.50	0.06	157.50	148.05	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2084	129	50	2024-03-03	6	17.50	0.06	105.00	98.70	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2085	75	43	2024-03-03	2	28.00	0.08	56.00	51.52	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2086	99	7	2024-03-03	7	90.00	0.08	630.00	579.60	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2087	29	18	2024-03-03	9	43.00	0.00	387.00	387.00	f	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2088	116	19	2024-03-03	2	38.00	0.08	76.00	69.92	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2089	132	41	2024-03-03	2	33.50	0.03	67.00	64.99	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2090	119	45	2024-03-03	6	59.50	0.04	357.00	342.72	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2091	102	30	2024-03-03	9	18.00	0.00	162.00	162.00	f	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2092	128	41	2024-03-03	7	33.50	0.01	234.50	232.16	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2093	24	52	2024-03-03	10	47.50	0.02	475.00	465.50	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2094	94	46	2024-03-03	9	25.50	0.01	229.50	227.20	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2095	16	41	2024-03-03	4	33.50	0.00	134.00	134.00	f	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2096	116	4	2024-03-03	5	10.00	0.07	50.00	46.50	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2097	148	38	2024-03-03	9	39.00	0.09	351.00	319.41	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2098	92	31	2024-03-03	8	37.00	0.01	296.00	293.04	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2099	28	16	2024-03-03	2	26.00	0.03	52.00	50.44	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2100	46	6	2024-03-03	1	25.00	0.10	25.00	22.50	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2101	33	11	2024-03-03	10	32.00	0.10	320.00	288.00	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2102	91	34	2024-03-03	10	9.50	0.08	95.00	87.40	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2103	114	47	2024-03-03	3	82.50	0.00	247.50	247.50	f	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2104	73	21	2024-03-04	7	34.00	0.05	238.00	226.10	t	0	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2105	53	6	2024-03-04	3	25.00	0.02	75.00	73.50	t	0	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2106	123	44	2024-03-04	8	10.50	0.07	84.00	78.12	t	0	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2107	144	20	2024-03-04	8	17.00	0.01	136.00	134.64	t	0	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2108	92	18	2024-03-04	6	43.00	0.07	258.00	239.94	t	0	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2109	89	29	2024-03-04	1	40.00	0.00	40.00	40.00	f	0	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2110	124	10	2024-03-04	1	15.00	0.04	15.00	14.40	t	0	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2111	91	52	2024-03-04	9	47.50	0.04	427.50	410.40	t	0	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2112	145	1	2024-03-04	1	30.00	0.10	30.00	27.00	t	0	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2113	133	21	2024-03-04	5	34.00	0.08	170.00	156.40	t	0	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2114	64	47	2024-03-04	5	82.50	0.10	412.50	371.25	t	0	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2115	79	8	2024-03-04	5	40.00	0.03	200.00	194.00	t	0	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2116	14	48	2024-03-04	1	44.50	0.00	44.50	44.50	f	0	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2117	98	34	2024-03-04	7	9.50	0.09	66.50	60.52	t	0	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2118	95	8	2024-03-04	2	40.00	0.06	80.00	75.20	t	0	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2119	104	37	2024-03-04	1	88.00	0.06	88.00	82.72	t	0	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2120	16	25	2024-03-05	3	65.00	0.01	195.00	193.05	t	1	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2121	30	33	2024-03-05	3	21.00	0.08	63.00	57.96	t	1	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2122	125	52	2024-03-05	9	47.50	0.02	427.50	418.95	t	1	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2123	17	26	2024-03-05	4	22.00	0.05	88.00	83.60	t	1	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2124	93	6	2024-03-05	9	25.00	0.02	225.00	220.50	t	1	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2125	11	47	2024-03-05	9	82.50	0.10	742.50	668.25	t	1	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2126	64	16	2024-03-05	10	26.00	0.09	260.00	236.60	t	1	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2127	118	34	2024-03-05	1	9.50	0.09	9.50	8.65	t	1	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2128	93	53	2024-03-05	6	22.50	0.04	135.00	129.60	t	1	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2129	21	14	2024-03-05	2	12.00	0.04	24.00	23.04	t	1	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2130	143	39	2024-03-05	9	35.00	0.07	315.00	292.95	t	1	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2131	63	30	2024-03-05	9	18.00	0.06	162.00	152.28	t	1	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2132	128	36	2024-03-05	6	26.50	0.01	159.00	157.41	t	1	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2133	25	40	2024-03-05	6	13.00	0.09	78.00	70.98	t	1	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2134	21	37	2024-03-06	10	88.00	0.05	880.00	836.00	t	2	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2135	33	14	2024-03-06	1	12.00	0.03	12.00	11.64	t	2	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2136	5	24	2024-03-06	2	11.00	0.07	22.00	20.46	t	2	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2137	39	36	2024-03-06	10	26.50	0.03	265.00	257.05	t	2	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2138	56	45	2024-03-06	6	59.50	0.08	357.00	328.44	t	2	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2139	141	4	2024-03-06	9	10.00	0.03	90.00	87.30	t	2	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2140	11	28	2024-03-06	5	46.00	0.10	230.00	207.00	t	2	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2141	44	1	2024-03-06	4	30.00	0.02	120.00	117.60	t	2	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2142	32	34	2024-03-06	9	9.50	0.09	85.50	77.81	t	2	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2143	12	42	2024-03-06	2	53.00	0.05	106.00	100.70	t	2	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2144	32	8	2024-03-06	2	40.00	0.04	80.00	76.80	t	2	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2145	30	20	2024-03-06	1	17.00	0.04	17.00	16.32	t	2	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2146	7	22	2024-03-06	10	54.00	0.03	540.00	523.80	t	2	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2147	98	22	2024-03-06	2	54.00	0.02	108.00	105.84	t	2	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2148	103	38	2024-03-06	3	39.00	0.06	117.00	109.98	t	2	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2149	93	29	2024-03-06	6	40.00	0.04	240.00	230.40	t	2	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2150	83	7	2024-03-06	3	90.00	0.02	270.00	264.60	t	2	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2151	112	46	2024-03-06	6	25.50	0.06	153.00	143.82	t	2	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2152	106	2	2024-03-06	2	50.00	0.07	100.00	93.00	t	2	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2153	79	43	2024-03-07	2	28.00	0.01	56.00	55.44	t	3	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2154	55	42	2024-03-07	10	53.00	0.01	530.00	524.70	t	3	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2155	21	51	2024-03-07	5	31.50	0.06	157.50	148.05	t	3	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2156	91	21	2024-03-07	10	34.00	0.04	340.00	326.40	t	3	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2157	69	17	2024-03-07	8	80.00	0.08	640.00	588.80	t	3	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2158	119	33	2024-03-07	1	21.00	0.06	21.00	19.74	t	3	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2159	82	35	2024-03-07	6	63.00	0.04	378.00	362.88	t	3	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2160	122	51	2024-03-07	5	31.50	0.09	157.50	143.33	t	3	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2161	68	3	2024-03-07	4	20.00	0.00	80.00	80.00	f	3	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2162	93	26	2024-03-07	2	22.00	0.02	44.00	43.12	t	3	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2163	73	23	2024-03-07	10	24.00	0.08	240.00	220.80	t	3	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2164	95	27	2024-03-07	3	85.00	0.01	255.00	252.45	t	3	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2165	85	28	2024-03-07	5	46.00	0.05	230.00	218.50	t	3	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2166	92	38	2024-03-07	6	39.00	0.03	234.00	226.98	t	3	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2167	64	39	2024-03-07	3	35.00	0.08	105.00	96.60	t	3	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2168	17	12	2024-03-07	10	44.00	0.03	440.00	426.80	t	3	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2169	132	18	2024-03-07	8	43.00	0.03	344.00	333.68	t	3	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2170	120	26	2024-03-07	1	22.00	0.09	22.00	20.02	t	3	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2171	90	16	2024-03-07	1	26.00	0.06	26.00	24.44	t	3	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2172	115	36	2024-03-07	8	26.50	0.02	212.00	207.76	t	3	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2173	32	49	2024-03-08	4	39.50	0.06	158.00	148.52	t	4	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2174	20	33	2024-03-08	7	21.00	0.08	147.00	135.24	t	4	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2175	146	45	2024-03-08	6	59.50	0.01	357.00	353.43	t	4	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2176	40	24	2024-03-08	6	11.00	0.04	66.00	63.36	t	4	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2177	68	35	2024-03-08	8	63.00	0.10	504.00	453.60	t	4	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2178	150	37	2024-03-08	6	88.00	0.06	528.00	496.32	t	4	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2179	91	31	2024-03-08	6	37.00	0.05	222.00	210.90	t	4	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2180	143	43	2024-03-08	3	28.00	0.09	84.00	76.44	t	4	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2181	52	53	2024-03-08	5	22.50	0.02	112.50	110.25	t	4	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2182	22	53	2024-03-08	6	22.50	0.04	135.00	129.60	t	4	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2183	33	42	2024-03-08	4	53.00	0.07	212.00	197.16	t	4	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2184	33	12	2024-03-08	6	44.00	0.08	264.00	242.88	t	4	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2185	14	50	2024-03-08	10	17.50	0.01	175.00	173.25	t	4	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2186	135	38	2024-03-08	10	39.00	0.01	390.00	386.10	t	4	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2187	111	38	2024-03-08	1	39.00	0.08	39.00	35.88	t	4	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2188	66	5	2024-03-08	4	60.00	0.07	240.00	223.20	t	4	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2189	2	52	2024-03-08	4	47.50	0.03	190.00	184.30	t	4	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2190	99	14	2024-03-08	8	12.00	0.08	96.00	88.32	t	4	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2191	36	47	2024-03-08	3	82.50	0.09	247.50	225.23	t	4	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2192	105	11	2024-03-08	9	32.00	0.02	288.00	282.24	t	4	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2193	111	4	2024-03-09	4	10.00	0.03	40.00	38.80	t	5	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2194	133	42	2024-03-09	3	53.00	0.05	159.00	151.05	t	5	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2195	57	13	2024-03-09	6	23.00	0.07	138.00	128.34	t	5	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2196	13	15	2024-03-09	2	70.00	0.08	140.00	128.80	t	5	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2197	8	30	2024-03-09	8	18.00	0.03	144.00	139.68	t	5	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2198	32	17	2024-03-09	8	80.00	0.08	640.00	588.80	t	5	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2199	104	27	2024-03-09	6	85.00	0.09	510.00	464.10	t	5	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2200	149	11	2024-03-09	9	32.00	0.01	288.00	285.12	t	5	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2201	44	7	2024-03-09	7	90.00	0.09	630.00	573.30	t	5	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2202	149	49	2024-03-09	5	39.50	0.08	197.50	181.70	t	5	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2203	103	32	2024-03-09	8	48.00	0.09	384.00	349.44	t	5	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2204	54	17	2024-03-09	1	80.00	0.06	80.00	75.20	t	5	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2205	89	42	2024-03-09	6	53.00	0.03	318.00	308.46	t	5	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2206	16	8	2024-03-09	9	40.00	0.06	360.00	338.40	t	5	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2207	77	5	2024-03-09	3	60.00	0.08	180.00	165.60	t	5	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2208	144	19	2024-03-09	3	38.00	0.04	114.00	109.44	t	5	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2209	25	45	2024-03-09	9	59.50	0.02	535.50	524.79	t	5	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2210	82	19	2024-03-10	3	38.00	0.07	114.00	106.02	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2211	145	31	2024-03-10	4	37.00	0.08	148.00	136.16	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2212	43	9	2024-03-10	6	36.00	0.07	216.00	200.88	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2213	82	48	2024-03-10	7	44.50	0.00	311.50	311.50	f	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2214	86	32	2024-03-10	8	48.00	0.07	384.00	357.12	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2215	118	19	2024-03-10	10	38.00	0.09	380.00	345.80	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2216	104	2	2024-03-10	9	50.00	0.06	450.00	423.00	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2217	96	50	2024-03-10	6	17.50	0.09	105.00	95.55	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2218	66	38	2024-03-10	10	39.00	0.00	390.00	390.00	f	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2219	85	44	2024-03-10	3	10.50	0.06	31.50	29.61	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2220	124	9	2024-03-10	1	36.00	0.00	36.00	36.00	f	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2221	74	3	2024-03-10	4	20.00	0.10	80.00	72.00	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2222	64	17	2024-03-10	1	80.00	0.09	80.00	72.80	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2223	146	44	2024-03-10	9	10.50	0.02	94.50	92.61	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2224	139	21	2024-03-10	10	34.00	0.05	340.00	323.00	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2225	88	48	2024-03-10	4	44.50	0.06	178.00	167.32	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2226	25	8	2024-03-10	4	40.00	0.01	160.00	158.40	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2227	93	44	2024-03-10	6	10.50	0.04	63.00	60.48	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2228	129	19	2024-03-10	6	38.00	0.10	228.00	205.20	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2229	122	35	2024-03-10	5	63.00	0.10	315.00	283.50	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2230	122	49	2024-03-10	8	39.50	0.02	316.00	309.68	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2231	107	17	2024-03-10	4	80.00	0.06	320.00	300.80	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2232	147	38	2024-03-10	4	39.00	0.07	156.00	145.08	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2233	34	28	2024-03-10	2	46.00	0.08	92.00	84.64	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2234	137	36	2024-03-10	8	26.50	0.02	212.00	207.76	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2235	87	21	2024-03-11	8	34.00	0.07	272.00	252.96	t	0	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2236	110	3	2024-03-11	10	20.00	0.07	200.00	186.00	t	0	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2237	8	46	2024-03-11	8	25.50	0.07	204.00	189.72	t	0	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2238	130	30	2024-03-11	1	18.00	0.05	18.00	17.10	t	0	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2239	119	49	2024-03-11	3	39.50	0.04	118.50	113.76	t	0	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2240	5	48	2024-03-11	2	44.50	0.07	89.00	82.77	t	0	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2241	56	36	2024-03-11	8	26.50	0.01	212.00	209.88	t	0	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2242	36	12	2024-03-11	6	44.00	0.07	264.00	245.52	t	0	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2243	138	43	2024-03-11	5	28.00	0.00	140.00	140.00	f	0	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2244	78	33	2024-03-11	3	21.00	0.03	63.00	61.11	t	0	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2245	74	26	2024-03-11	7	22.00	0.08	154.00	141.68	t	0	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2246	63	49	2024-03-11	1	39.50	0.03	39.50	38.32	t	0	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2247	45	34	2024-03-11	7	9.50	0.07	66.50	61.85	t	0	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2248	36	28	2024-03-12	9	46.00	0.06	414.00	389.16	t	1	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2249	34	37	2024-03-12	3	88.00	0.07	264.00	245.52	t	1	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2250	21	36	2024-03-12	9	26.50	0.03	238.50	231.35	t	1	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2251	72	1	2024-03-12	5	30.00	0.04	150.00	144.00	t	1	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2252	112	50	2024-03-12	1	17.50	0.01	17.50	17.33	t	1	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2253	119	7	2024-03-12	1	90.00	0.07	90.00	83.70	t	1	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2254	37	45	2024-03-12	6	59.50	0.09	357.00	324.87	t	1	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2255	106	32	2024-03-12	5	48.00	0.01	240.00	237.60	t	1	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2256	89	32	2024-03-12	4	48.00	0.06	192.00	180.48	t	1	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2257	61	46	2024-03-12	9	25.50	0.06	229.50	215.73	t	1	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2258	70	49	2024-03-12	3	39.50	0.06	118.50	111.39	t	1	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2259	37	3	2024-03-12	8	20.00	0.08	160.00	147.20	t	1	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2260	10	25	2024-03-12	3	65.00	0.07	195.00	181.35	t	1	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2261	107	35	2024-03-12	10	63.00	0.08	630.00	579.60	t	1	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2262	148	32	2024-03-12	5	48.00	0.03	240.00	232.80	t	1	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2263	96	13	2024-03-13	4	23.00	0.04	92.00	88.32	t	2	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2264	71	14	2024-03-13	1	12.00	0.03	12.00	11.64	t	2	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2265	110	1	2024-03-13	1	30.00	0.08	30.00	27.60	t	2	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2266	43	42	2024-03-13	6	53.00	0.06	318.00	298.92	t	2	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2267	94	37	2024-03-13	3	88.00	0.07	264.00	245.52	t	2	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2268	142	15	2024-03-13	7	70.00	0.06	490.00	460.60	t	2	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2269	35	40	2024-03-13	7	13.00	0.10	91.00	81.90	t	2	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2270	73	18	2024-03-13	9	43.00	0.08	387.00	356.04	t	2	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2271	121	11	2024-03-13	9	32.00	0.01	288.00	285.12	t	2	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2272	8	28	2024-03-13	1	46.00	0.07	46.00	42.78	t	2	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2273	132	7	2024-03-13	4	90.00	0.08	360.00	331.20	t	2	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2274	76	27	2024-03-13	4	85.00	0.06	340.00	319.60	t	2	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2275	135	10	2024-03-13	2	15.00	0.05	30.00	28.50	t	2	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2276	110	19	2024-03-13	4	38.00	0.04	152.00	145.92	t	2	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2277	74	30	2024-03-13	10	18.00	0.05	180.00	171.00	t	2	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2278	44	9	2024-03-13	4	36.00	0.04	144.00	138.24	t	2	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2279	8	21	2024-03-13	4	34.00	0.04	136.00	130.56	t	2	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2280	25	10	2024-03-13	10	15.00	0.09	150.00	136.50	t	2	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2281	84	7	2024-03-13	6	90.00	0.02	540.00	529.20	t	2	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2282	130	31	2024-03-14	1	37.00	0.06	37.00	34.78	t	3	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2283	60	17	2024-03-14	9	80.00	0.03	720.00	698.40	t	3	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2284	44	36	2024-03-14	10	26.50	0.05	265.00	251.75	t	3	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2285	64	23	2024-03-14	1	24.00	0.10	24.00	21.60	t	3	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2286	73	33	2024-03-14	4	21.00	0.07	84.00	78.12	t	3	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2287	60	13	2024-03-14	6	23.00	0.03	138.00	133.86	t	3	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2288	86	46	2024-03-14	2	25.50	0.01	51.00	50.49	t	3	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2289	87	51	2024-03-14	3	31.50	0.01	94.50	93.55	t	3	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2290	120	22	2024-03-14	7	54.00	0.06	378.00	355.32	t	3	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2291	100	17	2024-03-14	9	80.00	0.08	720.00	662.40	t	3	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2292	86	17	2024-03-14	7	80.00	0.01	560.00	554.40	t	3	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2293	4	12	2024-03-14	5	44.00	0.08	220.00	202.40	t	3	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2294	132	41	2024-03-14	7	33.50	0.03	234.50	227.47	t	3	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2295	70	33	2024-03-14	8	21.00	0.05	168.00	159.60	t	3	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2296	37	26	2024-03-14	9	22.00	0.02	198.00	194.04	t	3	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2297	36	46	2024-03-14	6	25.50	0.00	153.00	153.00	f	3	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2298	141	6	2024-03-14	4	25.00	0.05	100.00	95.00	t	3	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2299	148	3	2024-03-14	6	20.00	0.00	120.00	120.00	f	3	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2300	69	12	2024-03-14	3	44.00	0.02	132.00	129.36	t	3	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2301	96	35	2024-03-14	1	63.00	0.02	63.00	61.74	t	3	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2302	116	13	2024-03-14	1	23.00	0.08	23.00	21.16	t	3	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2303	97	14	2024-03-14	5	12.00	0.04	60.00	57.60	t	3	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2304	110	24	2024-03-14	4	11.00	0.08	44.00	40.48	t	3	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2305	15	47	2024-03-15	3	82.50	0.01	247.50	245.03	t	4	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2306	109	36	2024-03-15	1	26.50	0.08	26.50	24.38	t	4	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2307	98	39	2024-03-15	10	35.00	0.08	350.00	322.00	t	4	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2308	117	11	2024-03-15	1	32.00	0.05	32.00	30.40	t	4	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2309	147	42	2024-03-15	6	53.00	0.04	318.00	305.28	t	4	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2310	90	23	2024-03-15	7	24.00	0.04	168.00	161.28	t	4	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2311	79	45	2024-03-15	10	59.50	0.05	595.00	565.25	t	4	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2312	65	41	2024-03-15	3	33.50	0.05	100.50	95.48	t	4	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2313	52	11	2024-03-15	2	32.00	0.08	64.00	58.88	t	4	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2314	111	37	2024-03-15	3	88.00	0.09	264.00	240.24	t	4	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2315	102	20	2024-03-15	2	17.00	0.07	34.00	31.62	t	4	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2316	111	42	2024-03-15	10	53.00	0.02	530.00	519.40	t	4	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2317	68	47	2024-03-15	9	82.50	0.06	742.50	697.95	t	4	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2318	3	18	2024-03-15	5	43.00	0.03	215.00	208.55	t	4	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2319	75	36	2024-03-15	8	26.50	0.01	212.00	209.88	t	4	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2320	106	27	2024-03-16	6	85.00	0.05	510.00	484.50	t	5	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2321	1	10	2024-03-16	8	15.00	0.08	120.00	110.40	t	5	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2322	39	28	2024-03-16	8	46.00	0.03	368.00	356.96	t	5	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2323	149	11	2024-03-16	6	32.00	0.04	192.00	184.32	t	5	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2324	52	39	2024-03-16	8	35.00	0.05	280.00	266.00	t	5	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2325	39	22	2024-03-16	8	54.00	0.04	432.00	414.72	t	5	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2326	135	31	2024-03-16	10	37.00	0.06	370.00	347.80	t	5	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2327	40	16	2024-03-16	2	26.00	0.02	52.00	50.96	t	5	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2328	85	31	2024-03-16	10	37.00	0.05	370.00	351.50	t	5	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2329	34	15	2024-03-16	5	70.00	0.05	350.00	332.50	t	5	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2330	43	15	2024-03-16	7	70.00	0.02	490.00	480.20	t	5	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2331	41	42	2024-03-16	8	53.00	0.08	424.00	390.08	t	5	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2332	55	35	2024-03-16	1	63.00	0.03	63.00	61.11	t	5	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2333	65	2	2024-03-16	6	50.00	0.03	300.00	291.00	t	5	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2334	10	52	2024-03-16	1	47.50	0.04	47.50	45.60	t	5	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2335	53	51	2024-03-16	4	31.50	0.04	126.00	120.96	t	5	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2336	11	44	2024-03-17	7	10.50	0.06	73.50	69.09	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2337	9	35	2024-03-17	7	63.00	0.07	441.00	410.13	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2338	108	49	2024-03-17	1	39.50	0.05	39.50	37.53	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2339	28	46	2024-03-17	10	25.50	0.01	255.00	252.45	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2340	27	8	2024-03-17	10	40.00	0.08	400.00	368.00	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2341	40	36	2024-03-17	4	26.50	0.01	106.00	104.94	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2342	150	13	2024-03-17	2	23.00	0.01	46.00	45.54	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2343	89	41	2024-03-17	4	33.50	0.04	134.00	128.64	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2344	140	18	2024-03-17	5	43.00	0.08	215.00	197.80	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2345	69	45	2024-03-17	3	59.50	0.07	178.50	166.01	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2346	57	32	2024-03-17	7	48.00	0.08	336.00	309.12	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2347	104	43	2024-03-17	5	28.00	0.09	140.00	127.40	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2348	105	12	2024-03-17	4	44.00	0.04	176.00	168.96	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2349	12	4	2024-03-17	4	10.00	0.09	40.00	36.40	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2350	10	49	2024-03-17	2	39.50	0.04	79.00	75.84	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2351	57	22	2024-03-17	7	54.00	0.04	378.00	362.88	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2352	38	19	2024-03-17	9	38.00	0.02	342.00	335.16	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2353	27	20	2024-03-18	2	17.00	0.08	34.00	31.28	t	0	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2354	37	40	2024-03-18	6	13.00	0.02	78.00	76.44	t	0	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2355	138	10	2024-03-18	3	15.00	0.04	45.00	43.20	t	0	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2356	115	16	2024-03-18	3	26.00	0.07	78.00	72.54	t	0	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2357	42	21	2024-03-18	10	34.00	0.03	340.00	329.80	t	0	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2358	17	1	2024-03-18	4	30.00	0.05	120.00	114.00	t	0	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2359	124	26	2024-03-18	2	22.00	0.07	44.00	40.92	t	0	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2360	35	5	2024-03-18	7	60.00	0.08	420.00	386.40	t	0	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2361	45	51	2024-03-18	8	31.50	0.02	252.00	246.96	t	0	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2362	48	23	2024-03-18	8	24.00	0.10	192.00	172.80	t	0	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2363	53	33	2024-03-19	2	21.00	0.01	42.00	41.58	t	1	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2364	18	48	2024-03-19	9	44.50	0.04	400.50	384.48	t	1	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2365	104	52	2024-03-19	6	47.50	0.01	285.00	282.15	t	1	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2366	113	40	2024-03-19	7	13.00	0.02	91.00	89.18	t	1	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2367	116	6	2024-03-19	2	25.00	0.04	50.00	48.00	t	1	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2368	94	33	2024-03-19	7	21.00	0.06	147.00	138.18	t	1	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2369	149	42	2024-03-19	7	53.00	0.05	371.00	352.45	t	1	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2370	141	33	2024-03-19	8	21.00	0.00	168.00	168.00	f	1	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2371	30	30	2024-03-19	7	18.00	0.02	126.00	123.48	t	1	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2372	145	47	2024-03-19	7	82.50	0.01	577.50	571.73	t	1	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2373	71	23	2024-03-19	5	24.00	0.09	120.00	109.20	t	1	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2374	129	19	2024-03-19	2	38.00	0.00	76.00	76.00	f	1	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2375	10	2	2024-03-19	5	50.00	0.09	250.00	227.50	t	1	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2376	1	49	2024-03-19	7	39.50	0.04	276.50	265.44	t	1	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2377	20	13	2024-03-19	4	23.00	0.00	92.00	92.00	f	1	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2378	31	43	2024-03-19	5	28.00	0.01	140.00	138.60	t	1	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2379	60	24	2024-03-19	10	11.00	0.06	110.00	103.40	t	1	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2380	44	51	2024-03-19	6	31.50	0.03	189.00	183.33	t	1	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2381	30	18	2024-03-20	2	43.00	0.09	86.00	78.26	t	2	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2382	137	28	2024-03-20	4	46.00	0.00	184.00	184.00	f	2	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2383	111	25	2024-03-20	4	65.00	0.10	260.00	234.00	t	2	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2384	141	38	2024-03-20	9	39.00	0.06	351.00	329.94	t	2	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2385	130	50	2024-03-20	4	17.50	0.06	70.00	65.80	t	2	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2386	36	33	2024-03-20	1	21.00	0.09	21.00	19.11	t	2	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2387	19	27	2024-03-20	10	85.00	0.09	850.00	773.50	t	2	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2388	41	38	2024-03-20	5	39.00	0.10	195.00	175.50	t	2	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2389	112	2	2024-03-20	1	50.00	0.10	50.00	45.00	t	2	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2390	107	43	2024-03-20	5	28.00	0.01	140.00	138.60	t	2	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2391	67	22	2024-03-20	1	54.00	0.00	54.00	54.00	f	2	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2392	132	24	2024-03-20	7	11.00	0.10	77.00	69.30	t	2	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2393	149	53	2024-03-20	2	22.50	0.10	45.00	40.50	t	2	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2394	42	31	2024-03-20	7	37.00	0.01	259.00	256.41	t	2	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2395	79	8	2024-03-20	7	40.00	0.07	280.00	260.40	t	2	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2396	138	43	2024-03-20	3	28.00	0.05	84.00	79.80	t	2	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2397	29	26	2024-03-20	6	22.00	0.08	132.00	121.44	t	2	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2398	67	21	2024-03-21	2	34.00	0.02	68.00	66.64	t	3	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2399	128	45	2024-03-21	7	59.50	0.07	416.50	387.34	t	3	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2400	24	33	2024-03-21	2	21.00	0.09	42.00	38.22	t	3	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2401	28	17	2024-03-21	6	80.00	0.10	480.00	432.00	t	3	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2402	34	23	2024-03-21	5	24.00	0.05	120.00	114.00	t	3	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2403	69	50	2024-03-21	2	17.50	0.04	35.00	33.60	t	3	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2404	117	52	2024-03-21	8	47.50	0.02	380.00	372.40	t	3	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2405	50	52	2024-03-21	7	47.50	0.08	332.50	305.90	t	3	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2406	18	5	2024-03-21	1	60.00	0.02	60.00	58.80	t	3	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2407	23	51	2024-03-21	2	31.50	0.04	63.00	60.48	t	3	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2408	117	19	2024-03-21	2	38.00	0.07	76.00	70.68	t	3	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2409	84	40	2024-03-21	5	13.00	0.09	65.00	59.15	t	3	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2410	105	25	2024-03-21	8	65.00	0.08	520.00	478.40	t	3	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2411	82	20	2024-03-21	2	17.00	0.02	34.00	33.32	t	3	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2412	42	6	2024-03-21	2	25.00	0.10	50.00	45.00	t	3	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2413	107	49	2024-03-21	2	39.50	0.01	79.00	78.21	t	3	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2414	100	21	2024-03-21	8	34.00	0.10	272.00	244.80	t	3	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2415	79	14	2024-03-21	1	12.00	0.05	12.00	11.40	t	3	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2416	1	15	2024-03-21	8	70.00	0.03	560.00	543.20	t	3	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2417	115	27	2024-03-21	3	85.00	0.02	255.00	249.90	t	3	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2418	72	1	2024-03-22	9	30.00	0.00	270.00	270.00	f	4	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2419	130	53	2024-03-22	3	22.50	0.03	67.50	65.48	t	4	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2420	123	18	2024-03-22	8	43.00	0.07	344.00	319.92	t	4	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2421	147	9	2024-03-22	5	36.00	0.08	180.00	165.60	t	4	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2422	32	45	2024-03-22	7	59.50	0.02	416.50	408.17	t	4	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2423	129	6	2024-03-22	9	25.00	0.06	225.00	211.50	t	4	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2424	110	21	2024-03-22	1	34.00	0.02	34.00	33.32	t	4	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2425	143	28	2024-03-22	8	46.00	0.02	368.00	360.64	t	4	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2426	35	17	2024-03-22	3	80.00	0.09	240.00	218.40	t	4	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2427	88	35	2024-03-22	3	63.00	0.01	189.00	187.11	t	4	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2428	30	30	2024-03-22	10	18.00	0.02	180.00	176.40	t	4	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2429	94	1	2024-03-22	10	30.00	0.09	300.00	273.00	t	4	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2430	98	8	2024-03-22	9	40.00	0.04	360.00	345.60	t	4	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2431	98	9	2024-03-22	9	36.00	0.08	324.00	298.08	t	4	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2432	97	44	2024-03-22	5	10.50	0.07	52.50	48.82	t	4	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2433	141	25	2024-03-22	10	65.00	0.04	650.00	624.00	t	4	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2434	39	43	2024-03-23	1	28.00	0.01	28.00	27.72	t	5	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2435	24	3	2024-03-23	8	20.00	0.09	160.00	145.60	t	5	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2436	40	46	2024-03-23	7	25.50	0.03	178.50	173.14	t	5	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2437	104	11	2024-03-23	9	32.00	0.03	288.00	279.36	t	5	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2438	51	27	2024-03-23	5	85.00	0.01	425.00	420.75	t	5	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2439	90	10	2024-03-23	2	15.00	0.06	30.00	28.20	t	5	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2440	106	51	2024-03-23	10	31.50	0.00	315.00	315.00	f	5	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2441	150	43	2024-03-23	5	28.00	0.10	140.00	126.00	t	5	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2442	11	11	2024-03-23	8	32.00	0.05	256.00	243.20	t	5	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2443	36	43	2024-03-23	9	28.00	0.05	252.00	239.40	t	5	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2444	39	9	2024-03-23	10	36.00	0.08	360.00	331.20	t	5	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2445	111	8	2024-03-23	4	40.00	0.06	160.00	150.40	t	5	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2446	63	51	2024-03-23	5	31.50	0.02	157.50	154.35	t	5	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2447	119	42	2024-03-24	10	53.00	0.02	530.00	519.40	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2448	33	19	2024-03-24	9	38.00	0.04	342.00	328.32	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2449	34	1	2024-03-24	4	30.00	0.10	120.00	108.00	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2450	34	41	2024-03-24	6	33.50	0.06	201.00	188.94	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2451	20	42	2024-03-24	6	53.00	0.06	318.00	298.92	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2452	138	44	2024-03-24	7	10.50	0.03	73.50	71.30	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2453	3	14	2024-03-24	8	12.00	0.00	96.00	96.00	f	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2454	10	10	2024-03-24	8	15.00	0.05	120.00	114.00	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2455	141	33	2024-03-24	4	21.00	0.07	84.00	78.12	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2456	91	7	2024-03-24	2	90.00	0.09	180.00	163.80	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2457	135	10	2024-03-24	8	15.00	0.06	120.00	112.80	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2458	70	15	2024-03-24	4	70.00	0.05	280.00	266.00	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2459	140	33	2024-03-24	7	21.00	0.02	147.00	144.06	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2460	121	41	2024-03-24	5	33.50	0.07	167.50	155.77	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2461	143	10	2024-03-24	5	15.00	0.09	75.00	68.25	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2462	116	41	2024-03-24	2	33.50	0.02	67.00	65.66	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2463	123	53	2024-03-24	6	22.50	0.02	135.00	132.30	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2464	41	6	2024-03-24	2	25.00	0.04	50.00	48.00	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2465	14	3	2024-03-24	5	20.00	0.08	100.00	92.00	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2466	135	24	2024-03-24	6	11.00	0.07	66.00	61.38	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2467	81	27	2024-03-25	10	85.00	0.08	850.00	782.00	t	0	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2468	134	22	2024-03-25	6	54.00	0.04	324.00	311.04	t	0	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2469	101	47	2024-03-25	9	82.50	0.03	742.50	720.23	t	0	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2470	150	38	2024-03-25	7	39.00	0.03	273.00	264.81	t	0	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2471	109	28	2024-03-25	10	46.00	0.06	460.00	432.40	t	0	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2472	137	39	2024-03-25	6	35.00	0.01	210.00	207.90	t	0	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2473	21	18	2024-03-25	6	43.00	0.05	258.00	245.10	t	0	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2474	44	6	2024-03-25	7	25.00	0.09	175.00	159.25	t	0	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2475	118	42	2024-03-25	1	53.00	0.05	53.00	50.35	t	0	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2476	117	44	2024-03-25	5	10.50	0.09	52.50	47.78	t	0	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2477	132	8	2024-03-25	2	40.00	0.07	80.00	74.40	t	0	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2478	138	17	2024-03-25	3	80.00	0.01	240.00	237.60	t	0	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2479	144	11	2024-03-25	1	32.00	0.03	32.00	31.04	t	0	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2480	95	47	2024-03-25	6	82.50	0.06	495.00	465.30	t	0	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2481	11	45	2024-03-25	10	59.50	0.01	595.00	589.05	t	0	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2482	1	35	2024-03-26	1	63.00	0.08	63.00	57.96	t	1	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2483	68	31	2024-03-26	9	37.00	0.07	333.00	309.69	t	1	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2484	67	51	2024-03-26	2	31.50	0.06	63.00	59.22	t	1	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2485	84	41	2024-03-26	5	33.50	0.07	167.50	155.77	t	1	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2486	5	48	2024-03-26	2	44.50	0.03	89.00	86.33	t	1	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2487	53	37	2024-03-26	10	88.00	0.05	880.00	836.00	t	1	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2488	111	44	2024-03-26	10	10.50	0.00	105.00	105.00	f	1	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2489	74	28	2024-03-26	7	46.00	0.08	322.00	296.24	t	1	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2490	125	2	2024-03-26	10	50.00	0.03	500.00	485.00	t	1	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2491	111	18	2024-03-26	4	43.00	0.01	172.00	170.28	t	1	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2492	121	3	2024-03-26	4	20.00	0.07	80.00	74.40	t	1	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2493	73	22	2024-03-26	8	54.00	0.03	432.00	419.04	t	1	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2494	67	50	2024-03-26	1	17.50	0.04	17.50	16.80	t	1	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2495	108	21	2024-03-26	4	34.00	0.02	136.00	133.28	t	1	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2496	85	46	2024-03-26	4	25.50	0.08	102.00	93.84	t	1	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2497	149	27	2024-03-26	9	85.00	0.07	765.00	711.45	t	1	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2498	141	16	2024-03-26	8	26.00	0.03	208.00	201.76	t	1	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2499	144	28	2024-03-26	2	46.00	0.04	92.00	88.32	t	1	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2500	117	7	2024-03-26	5	90.00	0.07	450.00	418.50	t	1	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2501	8	22	2024-03-26	8	54.00	0.03	432.00	419.04	t	1	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2502	7	18	2024-03-27	8	43.00	0.03	344.00	333.68	t	2	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2503	32	35	2024-03-27	3	63.00	0.02	189.00	185.22	t	2	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2504	12	4	2024-03-27	10	10.00	0.04	100.00	96.00	t	2	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2505	6	11	2024-03-27	6	32.00	0.09	192.00	174.72	t	2	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2506	101	30	2024-03-27	6	18.00	0.04	108.00	103.68	t	2	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2507	55	22	2024-03-27	1	54.00	0.05	54.00	51.30	t	2	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2508	77	41	2024-03-27	1	33.50	0.03	33.50	32.50	t	2	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2509	13	50	2024-03-27	5	17.50	0.07	87.50	81.38	t	2	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2510	21	46	2024-03-27	10	25.50	0.06	255.00	239.70	t	2	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2511	111	50	2024-03-27	4	17.50	0.09	70.00	63.70	t	2	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2512	124	49	2024-03-27	5	39.50	0.04	197.50	189.60	t	2	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2513	8	22	2024-03-27	9	54.00	0.09	486.00	442.26	t	2	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2514	67	15	2024-03-27	5	70.00	0.04	350.00	336.00	t	2	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2515	96	20	2024-03-27	8	17.00	0.07	136.00	126.48	t	2	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2516	121	2	2024-03-27	3	50.00	0.07	150.00	139.50	t	2	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2517	134	49	2024-03-27	3	39.50	0.01	118.50	117.32	t	2	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2518	2	23	2024-03-27	1	24.00	0.09	24.00	21.84	t	2	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2519	55	48	2024-03-27	3	44.50	0.07	133.50	124.15	t	2	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2520	54	53	2024-03-27	4	22.50	0.05	90.00	85.50	t	2	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2521	12	21	2024-03-27	4	34.00	0.07	136.00	126.48	t	2	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2522	99	26	2024-03-27	7	22.00	0.09	154.00	140.14	t	2	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2523	27	30	2024-03-27	4	18.00	0.04	72.00	69.12	t	2	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2524	10	8	2024-03-27	9	40.00	0.08	360.00	331.20	t	2	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2525	31	16	2024-03-28	8	26.00	0.07	208.00	193.44	t	3	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2526	60	11	2024-03-28	9	32.00	0.01	288.00	285.12	t	3	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2527	2	29	2024-03-28	1	40.00	0.01	40.00	39.60	t	3	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2528	103	9	2024-03-28	4	36.00	0.06	144.00	135.36	t	3	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2529	8	37	2024-03-28	6	88.00	0.08	528.00	485.76	t	3	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2530	1	36	2024-03-28	4	26.50	0.06	106.00	99.64	t	3	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2531	70	46	2024-03-28	10	25.50	0.08	255.00	234.60	t	3	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2532	68	2	2024-03-28	9	50.00	0.06	450.00	423.00	t	3	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2533	140	19	2024-03-28	1	38.00	0.04	38.00	36.48	t	3	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2534	49	47	2024-03-28	2	82.50	0.09	165.00	150.15	t	3	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2535	53	2	2024-03-28	6	50.00	0.03	300.00	291.00	t	3	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2536	110	35	2024-03-28	2	63.00	0.09	126.00	114.66	t	3	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2537	82	30	2024-03-28	4	18.00	0.07	72.00	66.96	t	3	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2538	116	44	2024-03-28	10	10.50	0.09	105.00	95.55	t	3	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2539	71	10	2024-03-28	1	15.00	0.08	15.00	13.80	t	3	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2540	33	29	2024-03-28	9	40.00	0.08	360.00	331.20	t	3	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2541	67	3	2024-03-29	10	20.00	0.02	200.00	196.00	t	4	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2542	75	6	2024-03-29	5	25.00	0.07	125.00	116.25	t	4	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2543	112	1	2024-03-29	1	30.00	0.07	30.00	27.90	t	4	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2544	1	31	2024-03-29	7	37.00	0.01	259.00	256.41	t	4	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2545	8	14	2024-03-29	2	12.00	0.05	24.00	22.80	t	4	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2546	62	20	2024-03-29	6	17.00	0.03	102.00	98.94	t	4	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2547	10	15	2024-03-29	7	70.00	0.08	490.00	450.80	t	4	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2548	141	15	2024-03-29	2	70.00	0.02	140.00	137.20	t	4	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2549	111	50	2024-03-29	10	17.50	0.05	175.00	166.25	t	4	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2550	75	51	2024-03-29	4	31.50	0.05	126.00	119.70	t	4	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2551	27	7	2024-03-29	10	90.00	0.07	900.00	837.00	t	4	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2552	43	6	2024-03-30	3	25.00	0.09	75.00	68.25	t	5	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2553	51	42	2024-03-30	6	53.00	0.06	318.00	298.92	t	5	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2554	109	50	2024-03-30	1	17.50	0.02	17.50	17.15	t	5	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2555	61	49	2024-03-30	9	39.50	0.05	355.50	337.72	t	5	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2556	64	39	2024-03-30	8	35.00	0.09	280.00	254.80	t	5	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2557	24	1	2024-03-30	2	30.00	0.10	60.00	54.00	t	5	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2558	24	45	2024-03-30	1	59.50	0.02	59.50	58.31	t	5	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2559	48	11	2024-03-30	10	32.00	0.02	320.00	313.60	t	5	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2560	82	44	2024-03-30	4	10.50	0.09	42.00	38.22	t	5	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2561	66	45	2024-03-30	8	59.50	0.09	476.00	433.16	t	5	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2562	35	34	2024-03-30	2	9.50	0.03	19.00	18.43	t	5	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2563	57	10	2024-03-30	6	15.00	0.07	90.00	83.70	t	5	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2564	129	50	2024-03-30	7	17.50	0.05	122.50	116.38	t	5	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2565	31	48	2024-03-31	10	44.50	0.05	445.00	422.75	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2566	79	52	2024-03-31	5	47.50	0.02	237.50	232.75	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2567	105	26	2024-03-31	3	22.00	0.02	66.00	64.68	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2568	118	33	2024-03-31	8	21.00	0.08	168.00	154.56	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2569	121	18	2024-03-31	4	43.00	0.02	172.00	168.56	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2570	141	29	2024-03-31	6	40.00	0.07	240.00	223.20	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2571	52	33	2024-03-31	7	21.00	0.01	147.00	145.53	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2572	89	30	2024-03-31	3	18.00	0.10	54.00	48.60	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2573	98	48	2024-03-31	3	44.50	0.07	133.50	124.15	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2574	128	53	2024-03-31	7	22.50	0.06	157.50	148.05	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2575	7	10	2024-03-31	10	15.00	0.10	150.00	135.00	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2576	121	51	2024-03-31	10	31.50	0.06	315.00	296.10	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2577	141	6	2024-03-31	6	25.00	0.04	150.00	144.00	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2578	96	15	2024-03-31	10	70.00	0.05	700.00	665.00	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2579	96	27	2024-03-31	4	85.00	0.03	340.00	329.80	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2580	65	44	2024-03-31	3	10.50	0.03	31.50	30.56	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2581	62	32	2024-03-31	3	48.00	0.08	144.00	132.48	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2582	32	37	2024-03-31	9	88.00	0.09	792.00	720.72	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2583	58	32	2024-03-31	6	48.00	0.04	288.00	276.48	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2584	2	29	2024-03-31	10	40.00	0.01	400.00	396.00	t	6	3	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2585	103	7	2024-04-01	4	90.00	0.01	360.00	356.40	t	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2586	92	15	2024-04-01	2	70.00	0.00	140.00	140.00	f	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2587	15	3	2024-04-01	1	20.00	0.09	20.00	18.20	t	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2588	43	22	2024-04-01	2	54.00	0.01	108.00	106.92	t	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2589	68	2	2024-04-01	1	50.00	0.09	50.00	45.50	t	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2590	7	26	2024-04-01	7	22.00	0.00	154.00	154.00	f	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2591	134	16	2024-04-01	8	26.00	0.05	208.00	197.60	t	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2592	143	29	2024-04-01	6	40.00	0.04	240.00	230.40	t	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2593	132	11	2024-04-01	8	32.00	0.08	256.00	235.52	t	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2594	148	32	2024-04-01	5	48.00	0.05	240.00	228.00	t	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2595	49	15	2024-04-01	9	70.00	0.00	630.00	630.00	f	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2596	134	31	2024-04-01	6	37.00	0.10	222.00	199.80	t	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2597	23	20	2024-04-01	1	17.00	0.02	17.00	16.66	t	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2598	109	44	2024-04-01	8	10.50	0.09	84.00	76.44	t	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2599	4	11	2024-04-01	2	32.00	0.00	64.00	64.00	f	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2600	33	10	2024-04-01	5	15.00	0.07	75.00	69.75	t	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2601	105	12	2024-04-01	2	44.00	0.01	88.00	87.12	t	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2602	42	15	2024-04-01	3	70.00	0.05	210.00	199.50	t	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2603	99	48	2024-04-01	5	44.50	0.04	222.50	213.60	t	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2604	109	49	2024-04-01	7	39.50	0.05	276.50	262.68	t	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2605	146	35	2024-04-01	10	63.00	0.02	630.00	617.40	t	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2606	100	25	2024-04-01	1	65.00	0.00	65.00	65.00	f	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2607	38	8	2024-04-01	1	40.00	0.02	40.00	39.20	t	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2608	6	37	2024-04-01	5	88.00	0.00	440.00	440.00	f	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2609	112	48	2024-04-01	5	44.50	0.05	222.50	211.38	t	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2610	2	9	2024-04-01	1	36.00	0.01	36.00	35.64	t	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2611	126	42	2024-04-01	4	53.00	0.08	212.00	195.04	t	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2612	71	39	2024-04-02	9	35.00	0.05	315.00	299.25	t	1	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2613	65	29	2024-04-02	3	40.00	0.01	120.00	118.80	t	1	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2614	71	15	2024-04-02	8	70.00	0.03	560.00	543.20	t	1	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2615	74	34	2024-04-02	1	9.50	0.06	9.50	8.93	t	1	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2616	118	20	2024-04-02	10	17.00	0.04	170.00	163.20	t	1	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2617	103	36	2024-04-02	10	26.50	0.07	265.00	246.45	t	1	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2618	74	5	2024-04-02	9	60.00	0.01	540.00	534.60	t	1	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2619	60	30	2024-04-02	5	18.00	0.02	90.00	88.20	t	1	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2620	119	11	2024-04-02	3	32.00	0.07	96.00	89.28	t	1	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2621	127	24	2024-04-02	10	11.00	0.02	110.00	107.80	t	1	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2622	132	8	2024-04-02	10	40.00	0.04	400.00	384.00	t	1	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2623	3	9	2024-04-02	10	36.00	0.04	360.00	345.60	t	1	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2624	88	36	2024-04-02	10	26.50	0.01	265.00	262.35	t	1	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2625	74	38	2024-04-02	2	39.00	0.03	78.00	75.66	t	1	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2626	74	33	2024-04-03	9	21.00	0.01	189.00	187.11	t	2	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2627	91	50	2024-04-03	3	17.50	0.06	52.50	49.35	t	2	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2628	89	3	2024-04-03	9	20.00	0.09	180.00	163.80	t	2	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2629	150	38	2024-04-03	2	39.00	0.02	78.00	76.44	t	2	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2630	130	34	2024-04-03	5	9.50	0.09	47.50	43.23	t	2	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2631	65	16	2024-04-03	10	26.00	0.05	260.00	247.00	t	2	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2632	7	33	2024-04-03	5	21.00	0.05	105.00	99.75	t	2	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2633	112	6	2024-04-03	1	25.00	0.06	25.00	23.50	t	2	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2634	66	17	2024-04-03	1	80.00	0.04	80.00	76.80	t	2	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2635	140	50	2024-04-03	4	17.50	0.09	70.00	63.70	t	2	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2636	39	17	2024-04-03	8	80.00	0.04	640.00	614.40	t	2	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2637	119	19	2024-04-03	3	38.00	0.03	114.00	110.58	t	2	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2638	30	35	2024-04-03	4	63.00	0.08	252.00	231.84	t	2	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2639	123	31	2024-04-04	6	37.00	0.05	222.00	210.90	t	3	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2640	74	25	2024-04-04	6	65.00	0.06	390.00	366.60	t	3	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2641	122	46	2024-04-04	8	25.50	0.00	204.00	204.00	f	3	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2642	128	23	2024-04-04	8	24.00	0.08	192.00	176.64	t	3	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2643	100	25	2024-04-04	2	65.00	0.02	130.00	127.40	t	3	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2644	118	32	2024-04-04	5	48.00	0.04	240.00	230.40	t	3	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2645	99	17	2024-04-04	9	80.00	0.01	720.00	712.80	t	3	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2646	63	30	2024-04-04	1	18.00	0.06	18.00	16.92	t	3	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2647	45	12	2024-04-04	1	44.00	0.04	44.00	42.24	t	3	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2648	2	12	2024-04-04	9	44.00	0.06	396.00	372.24	t	3	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2649	21	30	2024-04-04	4	18.00	0.02	72.00	70.56	t	3	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2650	114	40	2024-04-04	9	13.00	0.10	117.00	105.30	t	3	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2651	2	45	2024-04-04	7	59.50	0.02	416.50	408.17	t	3	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2652	43	42	2024-04-04	1	53.00	0.06	53.00	49.82	t	3	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2653	95	44	2024-04-04	5	10.50	0.10	52.50	47.25	t	3	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2654	103	13	2024-04-04	8	23.00	0.02	184.00	180.32	t	3	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2655	76	25	2024-04-04	3	65.00	0.06	195.00	183.30	t	3	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2656	49	44	2024-04-05	8	10.50	0.00	84.00	84.00	f	4	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2657	64	32	2024-04-05	1	48.00	0.03	48.00	46.56	t	4	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2658	39	22	2024-04-05	10	54.00	0.03	540.00	523.80	t	4	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2659	135	24	2024-04-05	8	11.00	0.02	88.00	86.24	t	4	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2660	132	28	2024-04-05	7	46.00	0.02	322.00	315.56	t	4	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2661	139	43	2024-04-05	8	28.00	0.02	224.00	219.52	t	4	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2662	131	22	2024-04-05	6	54.00	0.01	324.00	320.76	t	4	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2663	10	12	2024-04-05	9	44.00	0.08	396.00	364.32	t	4	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2664	125	4	2024-04-05	4	10.00	0.01	40.00	39.60	t	4	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2665	116	15	2024-04-05	5	70.00	0.01	350.00	346.50	t	4	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2666	136	11	2024-04-05	2	32.00	0.09	64.00	58.24	t	4	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2667	111	2	2024-04-05	9	50.00	0.05	450.00	427.50	t	4	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2668	47	26	2024-04-05	2	22.00	0.02	44.00	43.12	t	4	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2669	71	26	2024-04-05	5	22.00	0.07	110.00	102.30	t	4	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2670	82	24	2024-04-05	6	11.00	0.02	66.00	64.68	t	4	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2671	124	30	2024-04-05	8	18.00	0.02	144.00	141.12	t	4	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2672	39	43	2024-04-05	4	28.00	0.02	112.00	109.76	t	4	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2673	15	39	2024-04-05	7	35.00	0.07	245.00	227.85	t	4	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2674	119	28	2024-04-06	6	46.00	0.02	276.00	270.48	t	5	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2675	68	19	2024-04-06	5	38.00	0.06	190.00	178.60	t	5	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2676	99	21	2024-04-06	6	34.00	0.04	204.00	195.84	t	5	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2677	146	46	2024-04-06	4	25.50	0.02	102.00	99.96	t	5	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2678	18	41	2024-04-06	8	33.50	0.04	268.00	257.28	t	5	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2679	79	1	2024-04-06	3	30.00	0.04	90.00	86.40	t	5	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2680	28	24	2024-04-06	7	11.00	0.00	77.00	77.00	f	5	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2681	74	28	2024-04-06	9	46.00	0.07	414.00	385.02	t	5	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2682	98	24	2024-04-06	9	11.00	0.08	99.00	91.08	t	5	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2683	93	12	2024-04-06	2	44.00	0.09	88.00	80.08	t	5	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2684	90	49	2024-04-06	1	39.50	0.08	39.50	36.34	t	5	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2685	21	19	2024-04-06	2	38.00	0.09	76.00	69.16	t	5	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2686	94	40	2024-04-06	5	13.00	0.05	65.00	61.75	t	5	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2687	8	53	2024-04-06	10	22.50	0.06	225.00	211.50	t	5	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2688	88	28	2024-04-06	4	46.00	0.07	184.00	171.12	t	5	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2689	143	12	2024-04-06	4	44.00	0.01	176.00	174.24	t	5	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2690	79	41	2024-04-06	4	33.50	0.04	134.00	128.64	t	5	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2691	130	49	2024-04-06	1	39.50	0.03	39.50	38.32	t	5	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2692	60	3	2024-04-06	9	20.00	0.06	180.00	169.20	t	5	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2693	27	26	2024-04-06	10	22.00	0.08	220.00	202.40	t	5	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2694	146	50	2024-04-06	5	17.50	0.05	87.50	83.13	t	5	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2695	6	17	2024-04-06	8	80.00	0.09	640.00	582.40	t	5	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2696	89	20	2024-04-06	4	17.00	0.01	68.00	67.32	t	5	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2697	100	39	2024-04-06	3	35.00	0.05	105.00	99.75	t	5	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2698	5	15	2024-04-06	3	70.00	0.08	210.00	193.20	t	5	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2699	9	52	2024-04-06	5	47.50	0.04	237.50	228.00	t	5	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2700	57	4	2024-04-06	3	10.00	0.02	30.00	29.40	t	5	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2701	111	44	2024-04-07	9	10.50	0.00	94.50	94.50	f	6	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2702	52	51	2024-04-07	3	31.50	0.03	94.50	91.66	t	6	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2703	26	16	2024-04-07	4	26.00	0.05	104.00	98.80	t	6	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2704	95	9	2024-04-07	9	36.00	0.01	324.00	320.76	t	6	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2705	32	13	2024-04-07	6	23.00	0.09	138.00	125.58	t	6	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2706	54	24	2024-04-07	3	11.00	0.07	33.00	30.69	t	6	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2707	106	14	2024-04-07	7	12.00	0.08	84.00	77.28	t	6	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2708	50	17	2024-04-07	3	80.00	0.08	240.00	220.80	t	6	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2709	21	15	2024-04-07	1	70.00	0.08	70.00	64.40	t	6	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2710	60	1	2024-04-07	7	30.00	0.05	210.00	199.50	t	6	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2711	24	48	2024-04-07	2	44.50	0.03	89.00	86.33	t	6	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2712	44	4	2024-04-07	9	10.00	0.08	90.00	82.80	t	6	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2713	46	15	2024-04-07	9	70.00	0.08	630.00	579.60	t	6	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2714	41	22	2024-04-07	3	54.00	0.09	162.00	147.42	t	6	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2715	2	34	2024-04-07	10	9.50	0.05	95.00	90.25	t	6	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2716	60	11	2024-04-07	9	32.00	0.08	288.00	264.96	t	6	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2717	55	32	2024-04-07	4	48.00	0.02	192.00	188.16	t	6	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2718	130	28	2024-04-08	10	46.00	0.06	460.00	432.40	t	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2719	85	7	2024-04-08	10	90.00	0.03	900.00	873.00	t	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2720	145	1	2024-04-08	10	30.00	0.06	300.00	282.00	t	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2721	26	51	2024-04-08	9	31.50	0.06	283.50	266.49	t	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2722	43	8	2024-04-08	9	40.00	0.05	360.00	342.00	t	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2723	75	47	2024-04-08	6	82.50	0.04	495.00	475.20	t	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2724	68	13	2024-04-08	6	23.00	0.05	138.00	131.10	t	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2725	62	24	2024-04-08	2	11.00	0.02	22.00	21.56	t	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2726	34	34	2024-04-08	1	9.50	0.03	9.50	9.22	t	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2727	29	29	2024-04-08	9	40.00	0.06	360.00	338.40	t	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2728	38	24	2024-04-08	8	11.00	0.01	88.00	87.12	t	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2729	40	20	2024-04-08	10	17.00	0.02	170.00	166.60	t	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2730	33	21	2024-04-08	7	34.00	0.03	238.00	230.86	t	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2731	87	52	2024-04-09	4	47.50	0.08	190.00	174.80	t	1	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2732	75	53	2024-04-09	7	22.50	0.09	157.50	143.33	t	1	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2733	130	50	2024-04-09	7	17.50	0.09	122.50	111.48	t	1	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2734	104	49	2024-04-09	5	39.50	0.04	197.50	189.60	t	1	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2735	110	16	2024-04-09	5	26.00	0.03	130.00	126.10	t	1	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2736	116	12	2024-04-09	5	44.00	0.05	220.00	209.00	t	1	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2737	2	17	2024-04-09	1	80.00	0.05	80.00	76.00	t	1	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2738	72	3	2024-04-09	7	20.00	0.08	140.00	128.80	t	1	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2739	6	31	2024-04-09	8	37.00	0.08	296.00	272.32	t	1	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2740	32	33	2024-04-09	10	21.00	0.07	210.00	195.30	t	1	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2741	122	14	2024-04-09	4	12.00	0.01	48.00	47.52	t	1	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2742	9	51	2024-04-09	9	31.50	0.05	283.50	269.33	t	1	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2743	39	27	2024-04-09	7	85.00	0.02	595.00	583.10	t	1	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2744	19	25	2024-04-09	1	65.00	0.05	65.00	61.75	t	1	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2745	48	48	2024-04-09	10	44.50	0.03	445.00	431.65	t	1	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2746	35	38	2024-04-09	5	39.00	0.09	195.00	177.45	t	1	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2747	136	38	2024-04-09	2	39.00	0.03	78.00	75.66	t	1	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2748	119	28	2024-04-10	5	46.00	0.08	230.00	211.60	t	2	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2749	116	20	2024-04-10	10	17.00	0.08	170.00	156.40	t	2	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2750	29	12	2024-04-10	7	44.00	0.08	308.00	283.36	t	2	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2751	96	25	2024-04-10	8	65.00	0.07	520.00	483.60	t	2	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2752	6	52	2024-04-10	6	47.50	0.03	285.00	276.45	t	2	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2753	130	37	2024-04-10	4	88.00	0.05	352.00	334.40	t	2	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2754	45	36	2024-04-10	2	26.50	0.08	53.00	48.76	t	2	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2755	90	3	2024-04-10	5	20.00	0.02	100.00	98.00	t	2	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2756	125	46	2024-04-10	6	25.50	0.03	153.00	148.41	t	2	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2757	107	27	2024-04-10	1	85.00	0.06	85.00	79.90	t	2	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2758	87	38	2024-04-10	6	39.00	0.05	234.00	222.30	t	2	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2759	64	50	2024-04-10	6	17.50	0.07	105.00	97.65	t	2	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2760	41	6	2024-04-10	3	25.00	0.05	75.00	71.25	t	2	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2761	116	49	2024-04-10	9	39.50	0.02	355.50	348.39	t	2	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2762	142	16	2024-04-10	2	26.00	0.06	52.00	48.88	t	2	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2763	137	50	2024-04-10	8	17.50	0.03	140.00	135.80	t	2	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2764	121	47	2024-04-11	8	82.50	0.07	660.00	613.80	t	3	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2765	35	24	2024-04-11	6	11.00	0.02	66.00	64.68	t	3	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2766	134	1	2024-04-11	3	30.00	0.05	90.00	85.50	t	3	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2767	137	37	2024-04-11	4	88.00	0.09	352.00	320.32	t	3	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2768	38	6	2024-04-11	3	25.00	0.03	75.00	72.75	t	3	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2769	69	7	2024-04-11	3	90.00	0.03	270.00	261.90	t	3	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2770	53	2	2024-04-11	3	50.00	0.03	150.00	145.50	t	3	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2771	130	40	2024-04-11	6	13.00	0.01	78.00	77.22	t	3	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2772	54	33	2024-04-11	4	21.00	0.07	84.00	78.12	t	3	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2773	116	42	2024-04-11	1	53.00	0.09	53.00	48.23	t	3	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2774	128	39	2024-04-11	7	35.00	0.10	245.00	220.50	t	3	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2775	119	13	2024-04-11	6	23.00	0.02	138.00	135.24	t	3	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2776	114	38	2024-04-11	3	39.00	0.04	117.00	112.32	t	3	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2777	24	18	2024-04-11	7	43.00	0.06	301.00	282.94	t	3	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2778	34	28	2024-04-11	1	46.00	0.08	46.00	42.32	t	3	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2779	136	28	2024-04-11	7	46.00	0.05	322.00	305.90	t	3	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2780	103	34	2024-04-11	6	9.50	0.00	57.00	57.00	f	3	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2781	11	9	2024-04-12	2	36.00	0.09	72.00	65.52	t	4	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2782	103	14	2024-04-12	7	12.00	0.05	84.00	79.80	t	4	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2783	146	51	2024-04-12	2	31.50	0.04	63.00	60.48	t	4	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2784	136	45	2024-04-12	1	59.50	0.07	59.50	55.33	t	4	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2785	58	27	2024-04-12	3	85.00	0.04	255.00	244.80	t	4	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2786	121	36	2024-04-12	1	26.50	0.03	26.50	25.71	t	4	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2787	86	8	2024-04-12	10	40.00	0.03	400.00	388.00	t	4	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2788	76	17	2024-04-12	4	80.00	0.03	320.00	310.40	t	4	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2789	15	34	2024-04-12	9	9.50	0.02	85.50	83.79	t	4	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2790	48	18	2024-04-12	4	43.00	0.08	172.00	158.24	t	4	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2791	97	52	2024-04-12	7	47.50	0.01	332.50	329.18	t	4	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2792	65	37	2024-04-12	7	88.00	0.09	616.00	560.56	t	4	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2793	77	41	2024-04-12	7	33.50	0.02	234.50	229.81	t	4	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2794	59	39	2024-04-12	10	35.00	0.10	350.00	315.00	t	4	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2795	56	8	2024-04-12	1	40.00	0.02	40.00	39.20	t	4	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2796	109	46	2024-04-12	2	25.50	0.06	51.00	47.94	t	4	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2797	25	48	2024-04-12	4	44.50	0.07	178.00	165.54	t	4	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2798	67	23	2024-04-12	9	24.00	0.00	216.00	216.00	f	4	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2799	72	18	2024-04-12	5	43.00	0.01	215.00	212.85	t	4	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2800	27	52	2024-04-12	8	47.50	0.08	380.00	349.60	t	4	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2801	86	5	2024-04-12	9	60.00	0.00	540.00	540.00	f	4	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2802	91	42	2024-04-12	4	53.00	0.03	212.00	205.64	t	4	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2803	65	18	2024-04-12	3	43.00	0.06	129.00	121.26	t	4	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2804	85	7	2024-04-12	8	90.00	0.05	720.00	684.00	t	4	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2805	114	39	2024-04-13	2	35.00	0.03	70.00	67.90	t	5	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2806	29	48	2024-04-13	5	44.50	0.09	222.50	202.48	t	5	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2807	127	47	2024-04-13	4	82.50	0.09	330.00	300.30	t	5	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2808	62	29	2024-04-13	1	40.00	0.01	40.00	39.60	t	5	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2809	81	12	2024-04-13	8	44.00	0.01	352.00	348.48	t	5	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2810	47	29	2024-04-13	4	40.00	0.04	160.00	153.60	t	5	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2811	27	29	2024-04-13	5	40.00	0.04	200.00	192.00	t	5	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2812	104	41	2024-04-13	5	33.50	0.05	167.50	159.13	t	5	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2813	85	16	2024-04-13	10	26.00	0.01	260.00	257.40	t	5	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2814	26	38	2024-04-13	9	39.00	0.05	351.00	333.45	t	5	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2815	51	10	2024-04-13	6	15.00	0.09	90.00	81.90	t	5	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2816	106	6	2024-04-13	1	25.00	0.03	25.00	24.25	t	5	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2817	68	45	2024-04-13	5	59.50	0.00	297.50	297.50	f	5	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2818	109	14	2024-04-13	4	12.00	0.00	48.00	48.00	f	5	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2819	44	26	2024-04-13	1	22.00	0.08	22.00	20.24	t	5	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2820	109	36	2024-04-13	1	26.50	0.03	26.50	25.71	t	5	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2821	72	26	2024-04-14	4	22.00	0.04	88.00	84.48	t	6	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2822	54	17	2024-04-14	5	80.00	0.04	400.00	384.00	t	6	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2823	145	1	2024-04-14	10	30.00	0.09	300.00	273.00	t	6	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2824	136	14	2024-04-14	6	12.00	0.08	72.00	66.24	t	6	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2825	124	16	2024-04-14	7	26.00	0.00	182.00	182.00	f	6	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2826	103	4	2024-04-14	3	10.00	0.05	30.00	28.50	t	6	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2827	144	53	2024-04-14	9	22.50	0.07	202.50	188.33	t	6	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2828	50	39	2024-04-14	3	35.00	0.03	105.00	101.85	t	6	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2829	43	14	2024-04-14	1	12.00	0.05	12.00	11.40	t	6	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2830	116	15	2024-04-14	1	70.00	0.09	70.00	63.70	t	6	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2831	45	27	2024-04-14	6	85.00	0.02	510.00	499.80	t	6	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2832	73	12	2024-04-14	2	44.00	0.03	88.00	85.36	t	6	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2833	109	8	2024-04-14	9	40.00	0.10	360.00	324.00	t	6	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2834	120	6	2024-04-14	2	25.00	0.02	50.00	49.00	t	6	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2835	43	26	2024-04-14	9	22.00	0.04	198.00	190.08	t	6	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2836	91	38	2024-04-14	9	39.00	0.08	351.00	322.92	t	6	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2837	8	6	2024-04-14	2	25.00	0.00	50.00	50.00	f	6	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2838	144	16	2024-04-14	10	26.00	0.08	260.00	239.20	t	6	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2839	118	18	2024-04-15	10	43.00	0.05	430.00	408.50	t	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2840	33	29	2024-04-15	5	40.00	0.10	200.00	180.00	t	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2841	61	38	2024-04-15	2	39.00	0.04	78.00	74.88	t	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2842	110	19	2024-04-15	10	38.00	0.05	380.00	361.00	t	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2843	82	6	2024-04-15	10	25.00	0.03	250.00	242.50	t	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2844	130	27	2024-04-15	1	85.00	0.10	85.00	76.50	t	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2845	37	17	2024-04-15	3	80.00	0.09	240.00	218.40	t	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2846	13	46	2024-04-15	4	25.50	0.08	102.00	93.84	t	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2847	85	53	2024-04-15	10	22.50	0.06	225.00	211.50	t	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2848	12	13	2024-04-15	10	23.00	0.01	230.00	227.70	t	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2849	135	19	2024-04-15	2	38.00	0.08	76.00	69.92	t	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2850	24	21	2024-04-15	5	34.00	0.05	170.00	161.50	t	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2851	99	17	2024-04-15	4	80.00	0.08	320.00	294.40	t	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2852	128	4	2024-04-15	8	10.00	0.06	80.00	75.20	t	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2853	86	9	2024-04-15	4	36.00	0.04	144.00	138.24	t	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2854	34	2	2024-04-15	7	50.00	0.09	350.00	318.50	t	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2855	150	51	2024-04-15	2	31.50	0.08	63.00	57.96	t	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2856	49	44	2024-04-15	5	10.50	0.01	52.50	51.98	t	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2857	107	2	2024-04-15	5	50.00	0.09	250.00	227.50	t	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2858	2	52	2024-04-15	9	47.50	0.01	427.50	423.23	t	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2859	94	52	2024-04-15	9	47.50	0.00	427.50	427.50	f	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2860	63	6	2024-04-15	1	25.00	0.06	25.00	23.50	t	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2861	16	44	2024-04-15	9	10.50	0.07	94.50	87.88	t	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2862	21	4	2024-04-15	2	10.00	0.02	20.00	19.60	t	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2863	32	42	2024-04-16	5	53.00	0.01	265.00	262.35	t	1	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2864	81	12	2024-04-16	6	44.00	0.07	264.00	245.52	t	1	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2865	18	12	2024-04-16	2	44.00	0.04	88.00	84.48	t	1	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2866	140	27	2024-04-16	1	85.00	0.06	85.00	79.90	t	1	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2867	48	38	2024-04-16	3	39.00	0.03	117.00	113.49	t	1	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2868	121	24	2024-04-16	6	11.00	0.03	66.00	64.02	t	1	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2869	45	3	2024-04-16	10	20.00	0.10	200.00	180.00	t	1	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2870	66	31	2024-04-16	7	37.00	0.04	259.00	248.64	t	1	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2871	118	34	2024-04-16	10	9.50	0.02	95.00	93.10	t	1	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2872	92	35	2024-04-16	3	63.00	0.02	189.00	185.22	t	1	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2873	59	23	2024-04-16	6	24.00	0.00	144.00	144.00	f	1	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2874	21	3	2024-04-16	1	20.00	0.06	20.00	18.80	t	1	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2875	130	42	2024-04-16	8	53.00	0.05	424.00	402.80	t	1	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2876	127	10	2024-04-16	5	15.00	0.06	75.00	70.50	t	1	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2877	113	46	2024-04-16	1	25.50	0.06	25.50	23.97	t	1	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2878	113	4	2024-04-17	10	10.00	0.04	100.00	96.00	t	2	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2879	106	18	2024-04-17	8	43.00	0.06	344.00	323.36	t	2	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2880	28	6	2024-04-17	7	25.00	0.01	175.00	173.25	t	2	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2881	90	43	2024-04-17	8	28.00	0.02	224.00	219.52	t	2	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2882	116	53	2024-04-17	3	22.50	0.03	67.50	65.48	t	2	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2883	100	39	2024-04-17	9	35.00	0.02	315.00	308.70	t	2	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2884	48	44	2024-04-17	9	10.50	0.05	94.50	89.77	t	2	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2885	10	11	2024-04-17	4	32.00	0.05	128.00	121.60	t	2	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2886	32	51	2024-04-17	1	31.50	0.06	31.50	29.61	t	2	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2887	139	51	2024-04-17	4	31.50	0.06	126.00	118.44	t	2	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2888	91	45	2024-04-17	9	59.50	0.10	535.50	481.95	t	2	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2889	130	52	2024-04-17	6	47.50	0.08	285.00	262.20	t	2	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2890	6	51	2024-04-17	1	31.50	0.10	31.50	28.35	t	2	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2891	20	17	2024-04-17	6	80.00	0.00	480.00	480.00	f	2	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2892	150	6	2024-04-17	3	25.00	0.04	75.00	72.00	t	2	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2893	60	22	2024-04-17	2	54.00	0.02	108.00	105.84	t	2	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2894	55	33	2024-04-17	9	21.00	0.04	189.00	181.44	t	2	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2895	6	21	2024-04-17	3	34.00	0.05	102.00	96.90	t	2	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2896	2	20	2024-04-17	5	17.00	0.01	85.00	84.15	t	2	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2897	82	26	2024-04-18	2	22.00	0.06	44.00	41.36	t	3	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2898	10	8	2024-04-18	10	40.00	0.07	400.00	372.00	t	3	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2899	10	52	2024-04-18	9	47.50	0.10	427.50	384.75	t	3	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2900	117	10	2024-04-18	5	15.00	0.03	75.00	72.75	t	3	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2901	29	27	2024-04-18	9	85.00	0.06	765.00	719.10	t	3	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2902	63	11	2024-04-18	7	32.00	0.05	224.00	212.80	t	3	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2903	31	3	2024-04-18	4	20.00	0.05	80.00	76.00	t	3	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2904	149	40	2024-04-18	10	13.00	0.05	130.00	123.50	t	3	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2905	26	7	2024-04-18	7	90.00	0.03	630.00	611.10	t	3	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2906	134	39	2024-04-18	10	35.00	0.03	350.00	339.50	t	3	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2907	49	24	2024-04-18	7	11.00	0.04	77.00	73.92	t	3	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2908	40	25	2024-04-19	7	65.00	0.02	455.00	445.90	t	4	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2909	26	50	2024-04-19	3	17.50	0.03	52.50	50.93	t	4	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2910	65	48	2024-04-19	9	44.50	0.01	400.50	396.50	t	4	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2911	4	17	2024-04-19	8	80.00	0.09	640.00	582.40	t	4	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2912	139	46	2024-04-19	10	25.50	0.02	255.00	249.90	t	4	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2913	86	49	2024-04-19	7	39.50	0.02	276.50	270.97	t	4	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2914	146	47	2024-04-19	3	82.50	0.03	247.50	240.08	t	4	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2915	7	1	2024-04-19	8	30.00	0.10	240.00	216.00	t	4	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2916	68	53	2024-04-19	3	22.50	0.05	67.50	64.13	t	4	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2917	94	2	2024-04-19	3	50.00	0.09	150.00	136.50	t	4	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2918	75	18	2024-04-19	3	43.00	0.07	129.00	119.97	t	4	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2919	96	16	2024-04-19	2	26.00	0.04	52.00	49.92	t	4	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2920	81	24	2024-04-19	5	11.00	0.08	55.00	50.60	t	4	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2921	131	3	2024-04-19	8	20.00	0.05	160.00	152.00	t	4	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2922	107	37	2024-04-19	1	88.00	0.09	88.00	80.08	t	4	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2923	135	17	2024-04-19	10	80.00	0.03	800.00	776.00	t	4	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2924	35	20	2024-04-19	9	17.00	0.01	153.00	151.47	t	4	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2925	97	41	2024-04-19	7	33.50	0.09	234.50	213.40	t	4	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2926	124	26	2024-04-19	7	22.00	0.07	154.00	143.22	t	4	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2927	76	26	2024-04-19	7	22.00	0.00	154.00	154.00	f	4	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2928	28	20	2024-04-19	3	17.00	0.10	51.00	45.90	t	4	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2929	99	20	2024-04-20	2	17.00	0.02	34.00	33.32	t	5	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2930	62	31	2024-04-20	10	37.00	0.09	370.00	336.70	t	5	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2931	34	24	2024-04-20	9	11.00	0.04	99.00	95.04	t	5	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2932	72	38	2024-04-20	10	39.00	0.06	390.00	366.60	t	5	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2933	85	47	2024-04-20	9	82.50	0.01	742.50	735.08	t	5	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2934	81	52	2024-04-20	6	47.50	0.01	285.00	282.15	t	5	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2935	21	37	2024-04-20	1	88.00	0.03	88.00	85.36	t	5	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2936	10	43	2024-04-20	6	28.00	0.09	168.00	152.88	t	5	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2937	5	34	2024-04-20	3	9.50	0.05	28.50	27.08	t	5	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2938	133	28	2024-04-20	9	46.00	0.08	414.00	380.88	t	5	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2939	12	6	2024-04-20	5	25.00	0.05	125.00	118.75	t	5	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2940	94	9	2024-04-20	10	36.00	0.06	360.00	338.40	t	5	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2941	22	3	2024-04-20	10	20.00	0.06	200.00	188.00	t	5	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2942	32	30	2024-04-21	8	18.00	0.03	144.00	139.68	t	6	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2943	34	38	2024-04-21	7	39.00	0.09	273.00	248.43	t	6	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2944	26	47	2024-04-21	5	82.50	0.05	412.50	391.88	t	6	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2945	105	26	2024-04-21	3	22.00	0.10	66.00	59.40	t	6	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2946	110	49	2024-04-21	10	39.50	0.07	395.00	367.35	t	6	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2947	29	25	2024-04-21	5	65.00	0.07	325.00	302.25	t	6	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2948	149	48	2024-04-21	4	44.50	0.06	178.00	167.32	t	6	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2949	146	31	2024-04-21	9	37.00	0.02	333.00	326.34	t	6	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2950	23	22	2024-04-21	6	54.00	0.02	324.00	317.52	t	6	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2951	109	52	2024-04-21	1	47.50	0.02	47.50	46.55	t	6	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2952	135	21	2024-04-21	9	34.00	0.05	306.00	290.70	t	6	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2953	107	24	2024-04-21	3	11.00	0.06	33.00	31.02	t	6	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2954	73	53	2024-04-21	7	22.50	0.05	157.50	149.63	t	6	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2955	110	16	2024-04-21	10	26.00	0.08	260.00	239.20	t	6	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2956	5	7	2024-04-21	1	90.00	0.01	90.00	89.10	t	6	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2957	134	32	2024-04-21	10	48.00	0.05	480.00	456.00	t	6	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2958	140	16	2024-04-21	3	26.00	0.06	78.00	73.32	t	6	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2959	85	7	2024-04-21	4	90.00	0.05	360.00	342.00	t	6	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2960	139	36	2024-04-21	4	26.50	0.09	106.00	96.46	t	6	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2961	127	33	2024-04-21	6	21.00	0.07	126.00	117.18	t	6	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2962	99	29	2024-04-21	5	40.00	0.10	200.00	180.00	t	6	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2963	16	48	2024-04-22	9	44.50	0.09	400.50	364.46	t	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2964	104	28	2024-04-22	5	46.00	0.00	230.00	230.00	f	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2965	63	16	2024-04-22	9	26.00	0.04	234.00	224.64	t	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2966	40	1	2024-04-22	4	30.00	0.00	120.00	120.00	f	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2967	90	18	2024-04-22	1	43.00	0.08	43.00	39.56	t	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2968	147	53	2024-04-22	6	22.50	0.02	135.00	132.30	t	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2969	29	5	2024-04-22	3	60.00	0.02	180.00	176.40	t	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2970	84	45	2024-04-22	8	59.50	0.09	476.00	433.16	t	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2971	23	46	2024-04-22	9	25.50	0.06	229.50	215.73	t	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2972	10	24	2024-04-22	1	11.00	0.06	11.00	10.34	t	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2973	91	52	2024-04-22	8	47.50	0.02	380.00	372.40	t	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2974	56	3	2024-04-22	5	20.00	0.01	100.00	99.00	t	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2975	56	35	2024-04-22	2	63.00	0.05	126.00	119.70	t	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2976	51	3	2024-04-22	5	20.00	0.02	100.00	98.00	t	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2977	142	53	2024-04-22	7	22.50	0.04	157.50	151.20	t	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2978	65	22	2024-04-22	9	54.00	0.06	486.00	456.84	t	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2979	108	30	2024-04-22	8	18.00	0.00	144.00	144.00	f	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2980	85	30	2024-04-22	9	18.00	0.01	162.00	160.38	t	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2981	67	45	2024-04-22	2	59.50	0.05	119.00	113.05	t	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2982	100	29	2024-04-23	4	40.00	0.01	160.00	158.40	t	1	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2983	71	19	2024-04-23	6	38.00	0.03	228.00	221.16	t	1	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2984	11	29	2024-04-23	2	40.00	0.01	80.00	79.20	t	1	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2985	96	25	2024-04-23	8	65.00	0.03	520.00	504.40	t	1	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2986	80	26	2024-04-23	10	22.00	0.04	220.00	211.20	t	1	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2987	111	16	2024-04-23	7	26.00	0.10	182.00	163.80	t	1	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2988	37	42	2024-04-23	2	53.00	0.07	106.00	98.58	t	1	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2989	27	39	2024-04-23	10	35.00	0.09	350.00	318.50	t	1	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2990	150	39	2024-04-23	4	35.00	0.01	140.00	138.60	t	1	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2991	106	4	2024-04-23	7	10.00	0.01	70.00	69.30	t	1	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2992	6	12	2024-04-23	1	44.00	0.01	44.00	43.56	t	1	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2993	145	48	2024-04-23	10	44.50	0.03	445.00	431.65	t	1	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2994	13	23	2024-04-23	6	24.00	0.09	144.00	131.04	t	1	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2995	38	7	2024-04-23	5	90.00	0.04	450.00	432.00	t	1	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2996	104	14	2024-04-23	9	12.00	0.10	108.00	97.20	t	1	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2997	16	1	2024-04-23	9	30.00	0.05	270.00	256.50	t	1	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2998	135	36	2024-04-23	3	26.50	0.07	79.50	73.93	t	1	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
2999	53	15	2024-04-23	10	70.00	0.01	700.00	693.00	t	1	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3000	28	53	2024-04-23	7	22.50	0.07	157.50	146.48	t	1	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3001	101	22	2024-04-23	9	54.00	0.05	486.00	461.70	t	1	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3002	74	22	2024-04-23	7	54.00	0.00	378.00	378.00	f	1	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3003	147	37	2024-04-23	1	88.00	0.01	88.00	87.12	t	1	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3004	62	1	2024-04-23	8	30.00	0.08	240.00	220.80	t	1	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3005	38	3	2024-04-24	9	20.00	0.04	180.00	172.80	t	2	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3006	37	40	2024-04-24	5	13.00	0.01	65.00	64.35	t	2	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3007	130	46	2024-04-24	8	25.50	0.09	204.00	185.64	t	2	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3008	78	48	2024-04-24	1	44.50	0.09	44.50	40.50	t	2	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3009	32	25	2024-04-24	10	65.00	0.03	650.00	630.50	t	2	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3010	133	24	2024-04-24	5	11.00	0.10	55.00	49.50	t	2	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3011	148	19	2024-04-24	6	38.00	0.03	228.00	221.16	t	2	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3012	126	42	2024-04-24	8	53.00	0.05	424.00	402.80	t	2	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3013	25	51	2024-04-25	10	31.50	0.00	315.00	315.00	f	3	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3014	35	26	2024-04-25	10	22.00	0.08	220.00	202.40	t	3	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3015	134	40	2024-04-25	9	13.00	0.00	117.00	117.00	f	3	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3016	1	10	2024-04-25	6	15.00	0.08	90.00	82.80	t	3	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3017	63	21	2024-04-25	8	34.00	0.06	272.00	255.68	t	3	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3018	107	6	2024-04-25	6	25.00	0.08	150.00	138.00	t	3	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3019	58	47	2024-04-25	7	82.50	0.09	577.50	525.53	t	3	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3020	4	17	2024-04-25	8	80.00	0.03	640.00	620.80	t	3	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3021	31	41	2024-04-25	4	33.50	0.07	134.00	124.62	t	3	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3022	80	41	2024-04-25	9	33.50	0.08	301.50	277.38	t	3	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3023	58	45	2024-04-25	5	59.50	0.00	297.50	297.50	f	3	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3024	55	53	2024-04-25	9	22.50	0.03	202.50	196.42	t	3	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3025	93	12	2024-04-25	9	44.00	0.02	396.00	388.08	t	3	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3026	67	11	2024-04-25	6	32.00	0.02	192.00	188.16	t	3	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3027	100	46	2024-04-25	5	25.50	0.09	127.50	116.03	t	3	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3028	103	10	2024-04-25	4	15.00	0.02	60.00	58.80	t	3	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3029	86	11	2024-04-25	5	32.00	0.00	160.00	160.00	f	3	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3030	89	9	2024-04-25	5	36.00	0.03	180.00	174.60	t	3	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3031	78	24	2024-04-26	1	11.00	0.10	11.00	9.90	t	4	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3032	24	20	2024-04-26	1	17.00	0.01	17.00	16.83	t	4	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3033	61	6	2024-04-26	10	25.00	0.08	250.00	230.00	t	4	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3034	86	31	2024-04-26	3	37.00	0.02	111.00	108.78	t	4	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3035	125	5	2024-04-26	5	60.00	0.06	300.00	282.00	t	4	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3036	72	28	2024-04-26	2	46.00	0.02	92.00	90.16	t	4	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3037	93	28	2024-04-26	3	46.00	0.07	138.00	128.34	t	4	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3038	69	16	2024-04-26	9	26.00	0.02	234.00	229.32	t	4	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3039	61	22	2024-04-26	9	54.00	0.01	486.00	481.14	t	4	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3040	146	26	2024-04-26	4	22.00	0.03	88.00	85.36	t	4	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3041	79	42	2024-04-26	5	53.00	0.00	265.00	265.00	f	4	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3042	61	52	2024-04-26	6	47.50	0.03	285.00	276.45	t	4	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3043	17	29	2024-04-26	8	40.00	0.01	320.00	316.80	t	4	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3044	136	34	2024-04-26	1	9.50	0.00	9.50	9.50	f	4	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3045	57	24	2024-04-26	9	11.00	0.08	99.00	91.08	t	4	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3046	48	13	2024-04-26	4	23.00	0.03	92.00	89.24	t	4	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3047	18	11	2024-04-26	3	32.00	0.08	96.00	88.32	t	4	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3048	16	11	2024-04-26	5	32.00	0.00	160.00	160.00	f	4	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3049	51	5	2024-04-26	2	60.00	0.00	120.00	120.00	f	4	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3050	90	39	2024-04-26	4	35.00	0.00	140.00	140.00	f	4	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3051	150	11	2024-04-27	10	32.00	0.05	320.00	304.00	t	5	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3052	136	9	2024-04-27	8	36.00	0.03	288.00	279.36	t	5	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3053	141	11	2024-04-27	4	32.00	0.07	128.00	119.04	t	5	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3054	22	23	2024-04-27	3	24.00	0.05	72.00	68.40	t	5	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3055	94	31	2024-04-27	3	37.00	0.01	111.00	109.89	t	5	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3056	11	23	2024-04-27	10	24.00	0.02	240.00	235.20	t	5	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3057	107	37	2024-04-27	10	88.00	0.04	880.00	844.80	t	5	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3058	103	10	2024-04-27	2	15.00	0.08	30.00	27.60	t	5	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3059	29	16	2024-04-27	4	26.00	0.05	104.00	98.80	t	5	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3060	90	51	2024-04-27	10	31.50	0.02	315.00	308.70	t	5	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3061	45	51	2024-04-27	3	31.50	0.05	94.50	89.77	t	5	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3062	139	46	2024-04-27	7	25.50	0.07	178.50	166.01	t	5	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3063	40	41	2024-04-27	4	33.50	0.06	134.00	125.96	t	5	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3064	40	21	2024-04-27	8	34.00	0.04	272.00	261.12	t	5	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3065	73	50	2024-04-27	10	17.50	0.01	175.00	173.25	t	5	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3066	22	18	2024-04-27	4	43.00	0.04	172.00	165.12	t	5	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3067	26	19	2024-04-27	4	38.00	0.00	152.00	152.00	f	5	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3068	32	25	2024-04-27	4	65.00	0.01	260.00	257.40	t	5	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3069	50	9	2024-04-27	1	36.00	0.10	36.00	32.40	t	5	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3070	101	30	2024-04-28	10	18.00	0.07	180.00	167.40	t	6	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3071	70	6	2024-04-28	9	25.00	0.08	225.00	207.00	t	6	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3072	62	23	2024-04-28	10	24.00	0.01	240.00	237.60	t	6	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3073	128	36	2024-04-28	2	26.50	0.09	53.00	48.23	t	6	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3074	83	8	2024-04-28	8	40.00	0.08	320.00	294.40	t	6	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3075	92	19	2024-04-28	10	38.00	0.01	380.00	376.20	t	6	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3076	49	7	2024-04-28	5	90.00	0.04	450.00	432.00	t	6	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3077	10	1	2024-04-28	2	30.00	0.01	60.00	59.40	t	6	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3078	75	38	2024-04-29	10	39.00	0.02	390.00	382.20	t	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3079	72	6	2024-04-29	9	25.00	0.06	225.00	211.50	t	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3080	35	49	2024-04-29	3	39.50	0.09	118.50	107.84	t	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3081	128	53	2024-04-29	3	22.50	0.01	67.50	66.83	t	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3082	102	33	2024-04-29	5	21.00	0.01	105.00	103.95	t	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3083	88	37	2024-04-29	3	88.00	0.05	264.00	250.80	t	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3084	121	29	2024-04-29	5	40.00	0.03	200.00	194.00	t	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3085	40	43	2024-04-29	6	28.00	0.02	168.00	164.64	t	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3086	137	50	2024-04-29	9	17.50	0.02	157.50	154.35	t	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3087	79	26	2024-04-29	10	22.00	0.05	220.00	209.00	t	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3088	96	40	2024-04-29	3	13.00	0.01	39.00	38.61	t	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3089	55	6	2024-04-29	7	25.00	0.00	175.00	175.00	f	0	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3090	42	4	2024-04-30	7	10.00	0.08	70.00	64.40	t	1	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3091	40	15	2024-04-30	8	70.00	0.04	560.00	537.60	t	1	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3092	149	45	2024-04-30	8	59.50	0.08	476.00	437.92	t	1	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3093	124	35	2024-04-30	7	63.00	0.03	441.00	427.77	t	1	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3094	38	46	2024-04-30	4	25.50	0.01	102.00	100.98	t	1	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3095	145	28	2024-04-30	1	46.00	0.01	46.00	45.54	t	1	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3096	15	46	2024-04-30	1	25.50	0.04	25.50	24.48	t	1	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3097	135	44	2024-04-30	8	10.50	0.00	84.00	84.00	f	1	4	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3098	43	38	2024-05-01	2	39.00	0.06	78.00	73.32	t	2	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3099	23	47	2024-05-01	3	82.50	0.01	247.50	245.03	t	2	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3100	13	29	2024-05-01	2	40.00	0.00	80.00	80.00	f	2	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3101	150	31	2024-05-01	4	37.00	0.04	148.00	142.08	t	2	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3102	133	21	2024-05-01	10	34.00	0.08	340.00	312.80	t	2	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3103	116	27	2024-05-01	7	85.00	0.07	595.00	553.35	t	2	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3104	32	40	2024-05-01	8	13.00	0.07	104.00	96.72	t	2	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3105	75	34	2024-05-01	3	9.50	0.01	28.50	28.22	t	2	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3106	32	6	2024-05-01	10	25.00	0.02	250.00	245.00	t	2	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3107	145	34	2024-05-01	8	9.50	0.08	76.00	69.92	t	2	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3108	67	53	2024-05-01	9	22.50	0.07	202.50	188.33	t	2	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3109	1	53	2024-05-01	4	22.50	0.08	90.00	82.80	t	2	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3110	24	8	2024-05-01	10	40.00	0.01	400.00	396.00	t	2	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3111	123	25	2024-05-01	4	65.00	0.06	260.00	244.40	t	2	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3112	9	47	2024-05-01	3	82.50	0.07	247.50	230.17	t	2	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3113	11	9	2024-05-01	1	36.00	0.06	36.00	33.84	t	2	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3114	141	9	2024-05-01	9	36.00	0.03	324.00	314.28	t	2	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3115	93	36	2024-05-02	4	26.50	0.04	106.00	101.76	t	3	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3116	127	26	2024-05-02	2	22.00	0.04	44.00	42.24	t	3	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3117	59	2	2024-05-02	9	50.00	0.04	450.00	432.00	t	3	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3118	56	52	2024-05-02	3	47.50	0.05	142.50	135.38	t	3	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3119	7	4	2024-05-02	7	10.00	0.02	70.00	68.60	t	3	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3120	21	53	2024-05-02	3	22.50	0.03	67.50	65.48	t	3	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3121	18	21	2024-05-02	5	34.00	0.04	170.00	163.20	t	3	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3122	133	26	2024-05-02	10	22.00	0.05	220.00	209.00	t	3	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3123	9	31	2024-05-02	3	37.00	0.07	111.00	103.23	t	3	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3124	140	19	2024-05-02	7	38.00	0.04	266.00	255.36	t	3	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3125	85	46	2024-05-02	4	25.50	0.02	102.00	99.96	t	3	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3126	52	29	2024-05-02	6	40.00	0.04	240.00	230.40	t	3	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3127	104	10	2024-05-02	4	15.00	0.03	60.00	58.20	t	3	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3128	138	9	2024-05-02	9	36.00	0.02	324.00	317.52	t	3	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3129	89	53	2024-05-03	9	22.50	0.06	202.50	190.35	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3130	68	47	2024-05-03	2	82.50	0.05	165.00	156.75	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3131	136	24	2024-05-03	10	11.00	0.05	110.00	104.50	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3132	113	8	2024-05-03	4	40.00	0.03	160.00	155.20	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3133	7	48	2024-05-03	10	44.50	0.07	445.00	413.85	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3134	51	1	2024-05-03	1	30.00	0.02	30.00	29.40	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3135	106	18	2024-05-03	3	43.00	0.03	129.00	125.13	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3136	95	29	2024-05-03	4	40.00	0.07	160.00	148.80	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3137	113	8	2024-05-03	2	40.00	0.01	80.00	79.20	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3138	101	49	2024-05-03	5	39.50	0.09	197.50	179.73	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3139	78	25	2024-05-03	8	65.00	0.10	520.00	468.00	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3140	146	28	2024-05-03	5	46.00	0.08	230.00	211.60	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3141	26	8	2024-05-03	10	40.00	0.01	400.00	396.00	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3142	127	41	2024-05-03	8	33.50	0.06	268.00	251.92	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3143	40	26	2024-05-03	1	22.00	0.05	22.00	20.90	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3144	43	36	2024-05-03	5	26.50	0.06	132.50	124.55	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3145	141	6	2024-05-03	1	25.00	0.03	25.00	24.25	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3146	97	43	2024-05-03	1	28.00	0.07	28.00	26.04	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3147	69	11	2024-05-03	10	32.00	0.05	320.00	304.00	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3148	7	31	2024-05-03	10	37.00	0.07	370.00	344.10	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3149	57	35	2024-05-03	2	63.00	0.07	126.00	117.18	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3150	101	13	2024-05-03	3	23.00	0.04	69.00	66.24	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3151	139	15	2024-05-03	5	70.00	0.09	350.00	318.50	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3152	51	8	2024-05-03	4	40.00	0.03	160.00	155.20	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3153	77	28	2024-05-03	9	46.00	0.04	414.00	397.44	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3154	9	12	2024-05-03	1	44.00	0.09	44.00	40.04	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3155	30	35	2024-05-03	4	63.00	0.05	252.00	239.40	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3156	145	16	2024-05-04	1	26.00	0.02	26.00	25.48	t	5	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3157	115	1	2024-05-04	6	30.00	0.06	180.00	169.20	t	5	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3158	127	19	2024-05-04	3	38.00	0.10	114.00	102.60	t	5	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3159	144	28	2024-05-04	1	46.00	0.07	46.00	42.78	t	5	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3160	29	1	2024-05-04	4	30.00	0.01	120.00	118.80	t	5	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3161	137	48	2024-05-04	9	44.50	0.01	400.50	396.50	t	5	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3162	49	7	2024-05-04	9	90.00	0.07	810.00	753.30	t	5	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3163	114	11	2024-05-04	6	32.00	0.03	192.00	186.24	t	5	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3164	145	14	2024-05-04	8	12.00	0.02	96.00	94.08	t	5	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3165	121	50	2024-05-04	10	17.50	0.02	175.00	171.50	t	5	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3166	130	11	2024-05-04	3	32.00	0.02	96.00	94.08	t	5	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3167	94	18	2024-05-04	8	43.00	0.04	344.00	330.24	t	5	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3168	98	17	2024-05-04	10	80.00	0.09	800.00	728.00	t	5	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3169	64	10	2024-05-04	9	15.00	0.05	135.00	128.25	t	5	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3170	121	29	2024-05-04	2	40.00	0.02	80.00	78.40	t	5	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3171	98	40	2024-05-04	6	13.00	0.07	78.00	72.54	t	5	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3172	133	13	2024-05-04	6	23.00	0.09	138.00	125.58	t	5	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3173	12	14	2024-05-05	5	12.00	0.03	60.00	58.20	t	6	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3174	70	32	2024-05-05	4	48.00	0.10	192.00	172.80	t	6	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3175	39	22	2024-05-05	8	54.00	0.06	432.00	406.08	t	6	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3176	95	52	2024-05-05	7	47.50	0.09	332.50	302.58	t	6	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3177	32	18	2024-05-05	8	43.00	0.08	344.00	316.48	t	6	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3178	146	39	2024-05-05	6	35.00	0.03	210.00	203.70	t	6	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3179	144	50	2024-05-05	6	17.50	0.03	105.00	101.85	t	6	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3180	146	20	2024-05-05	8	17.00	0.10	136.00	122.40	t	6	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3181	1	19	2024-05-05	8	38.00	0.04	304.00	291.84	t	6	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3182	139	11	2024-05-05	9	32.00	0.02	288.00	282.24	t	6	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3183	4	47	2024-05-05	1	82.50	0.08	82.50	75.90	t	6	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3184	106	22	2024-05-05	4	54.00	0.02	216.00	211.68	t	6	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3185	9	21	2024-05-05	4	34.00	0.04	136.00	130.56	t	6	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3186	3	34	2024-05-05	8	9.50	0.04	76.00	72.96	t	6	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3187	147	45	2024-05-05	10	59.50	0.00	595.00	595.00	f	6	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3188	67	48	2024-05-05	9	44.50	0.09	400.50	364.46	t	6	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3189	16	20	2024-05-05	5	17.00	0.01	85.00	84.15	t	6	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3190	106	6	2024-05-06	7	25.00	0.03	175.00	169.75	t	0	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3191	136	21	2024-05-06	5	34.00	0.01	170.00	168.30	t	0	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3192	37	52	2024-05-06	5	47.50	0.09	237.50	216.13	t	0	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3193	128	34	2024-05-06	7	9.50	0.07	66.50	61.85	t	0	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3194	143	37	2024-05-06	7	88.00	0.02	616.00	603.68	t	0	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3195	84	48	2024-05-06	10	44.50	0.05	445.00	422.75	t	0	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3196	41	48	2024-05-06	8	44.50	0.06	356.00	334.64	t	0	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3197	145	6	2024-05-06	9	25.00	0.04	225.00	216.00	t	0	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3198	51	9	2024-05-06	6	36.00	0.06	216.00	203.04	t	0	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3199	40	52	2024-05-06	4	47.50	0.07	190.00	176.70	t	0	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3200	6	40	2024-05-06	4	13.00	0.08	52.00	47.84	t	0	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3201	49	8	2024-05-06	1	40.00	0.08	40.00	36.80	t	0	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3202	90	38	2024-05-06	7	39.00	0.09	273.00	248.43	t	0	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3203	103	19	2024-05-06	5	38.00	0.04	190.00	182.40	t	0	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3204	109	33	2024-05-06	6	21.00	0.09	126.00	114.66	t	0	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3205	109	35	2024-05-06	6	63.00	0.01	378.00	374.22	t	0	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3206	49	5	2024-05-07	2	60.00	0.01	120.00	118.80	t	1	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3207	55	38	2024-05-07	6	39.00	0.02	234.00	229.32	t	1	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3208	122	26	2024-05-07	3	22.00	0.09	66.00	60.06	t	1	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3209	60	9	2024-05-07	8	36.00	0.07	288.00	267.84	t	1	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3210	39	24	2024-05-07	4	11.00	0.08	44.00	40.48	t	1	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3211	80	18	2024-05-07	9	43.00	0.10	387.00	348.30	t	1	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3212	93	11	2024-05-07	3	32.00	0.02	96.00	94.08	t	1	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3213	11	19	2024-05-07	5	38.00	0.02	190.00	186.20	t	1	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3214	33	23	2024-05-08	6	24.00	0.03	144.00	139.68	t	2	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3215	86	15	2024-05-08	9	70.00	0.02	630.00	617.40	t	2	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3216	33	37	2024-05-08	8	88.00	0.01	704.00	696.96	t	2	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3217	108	23	2024-05-08	5	24.00	0.05	120.00	114.00	t	2	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3218	45	1	2024-05-08	10	30.00	0.06	300.00	282.00	t	2	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3219	111	11	2024-05-08	5	32.00	0.08	160.00	147.20	t	2	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3220	7	31	2024-05-08	4	37.00	0.08	148.00	136.16	t	2	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3221	119	43	2024-05-08	9	28.00	0.10	252.00	226.80	t	2	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3222	130	6	2024-05-08	3	25.00	0.01	75.00	74.25	t	2	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3223	148	33	2024-05-08	9	21.00	0.00	189.00	189.00	f	2	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3224	26	6	2024-05-08	1	25.00	0.10	25.00	22.50	t	2	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3225	31	1	2024-05-08	4	30.00	0.01	120.00	118.80	t	2	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3226	29	52	2024-05-08	6	47.50	0.09	285.00	259.35	t	2	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3227	96	18	2024-05-08	9	43.00	0.06	387.00	363.78	t	2	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3228	119	35	2024-05-08	5	63.00	0.02	315.00	308.70	t	2	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3229	87	39	2024-05-08	7	35.00	0.03	245.00	237.65	t	2	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3230	144	26	2024-05-08	6	22.00	0.02	132.00	129.36	t	2	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3231	106	48	2024-05-09	2	44.50	0.06	89.00	83.66	t	3	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3232	126	44	2024-05-09	6	10.50	0.00	63.00	63.00	f	3	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3233	129	16	2024-05-09	9	26.00	0.00	234.00	234.00	f	3	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3234	20	48	2024-05-09	2	44.50	0.00	89.00	89.00	f	3	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3235	104	36	2024-05-09	5	26.50	0.08	132.50	121.90	t	3	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3236	117	20	2024-05-09	5	17.00	0.01	85.00	84.15	t	3	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3237	3	47	2024-05-09	10	82.50	0.03	825.00	800.25	t	3	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3238	148	31	2024-05-09	3	37.00	0.07	111.00	103.23	t	3	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3239	39	26	2024-05-09	2	22.00	0.03	44.00	42.68	t	3	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3240	140	37	2024-05-09	1	88.00	0.01	88.00	87.12	t	3	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3241	114	13	2024-05-09	9	23.00	0.08	207.00	190.44	t	3	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3242	77	33	2024-05-09	2	21.00	0.06	42.00	39.48	t	3	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3243	101	30	2024-05-09	6	18.00	0.08	108.00	99.36	t	3	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3244	25	43	2024-05-09	2	28.00	0.06	56.00	52.64	t	3	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3245	115	38	2024-05-09	7	39.00	0.04	273.00	262.08	t	3	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3246	22	26	2024-05-09	9	22.00	0.06	198.00	186.12	t	3	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3247	139	22	2024-05-10	3	54.00	0.04	162.00	155.52	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3248	139	53	2024-05-10	5	22.50	0.04	112.50	108.00	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3249	116	40	2024-05-10	3	13.00	0.09	39.00	35.49	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3250	17	36	2024-05-10	4	26.50	0.06	106.00	99.64	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3251	110	45	2024-05-10	9	59.50	0.09	535.50	487.31	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3252	49	23	2024-05-10	9	24.00	0.01	216.00	213.84	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3253	33	31	2024-05-10	4	37.00	0.09	148.00	134.68	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3254	89	3	2024-05-10	8	20.00	0.02	160.00	156.80	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3255	88	41	2024-05-10	3	33.50	0.06	100.50	94.47	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3256	78	6	2024-05-10	9	25.00	0.05	225.00	213.75	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3257	139	37	2024-05-10	7	88.00	0.01	616.00	609.84	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3258	27	48	2024-05-10	2	44.50	0.08	89.00	81.88	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3259	116	9	2024-05-10	4	36.00	0.06	144.00	135.36	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3260	24	46	2024-05-11	1	25.50	0.05	25.50	24.22	t	5	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3261	81	19	2024-05-11	1	38.00	0.09	38.00	34.58	t	5	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3262	26	44	2024-05-11	1	10.50	0.05	10.50	9.98	t	5	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3263	16	12	2024-05-11	6	44.00	0.01	264.00	261.36	t	5	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3264	60	40	2024-05-11	4	13.00	0.00	52.00	52.00	f	5	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3265	14	20	2024-05-11	5	17.00	0.08	85.00	78.20	t	5	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3266	27	6	2024-05-11	9	25.00	0.03	225.00	218.25	t	5	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3267	62	50	2024-05-11	3	17.50	0.06	52.50	49.35	t	5	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3268	8	44	2024-05-11	6	10.50	0.08	63.00	57.96	t	5	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3269	78	40	2024-05-11	2	13.00	0.04	26.00	24.96	t	5	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3270	120	29	2024-05-11	7	40.00	0.01	280.00	277.20	t	5	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3271	113	41	2024-05-11	1	33.50	0.10	33.50	30.15	t	5	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3272	134	47	2024-05-11	3	82.50	0.09	247.50	225.23	t	5	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3273	105	47	2024-05-11	9	82.50	0.10	742.50	668.25	t	5	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3274	89	17	2024-05-11	9	80.00	0.09	720.00	655.20	t	5	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3275	21	45	2024-05-11	7	59.50	0.03	416.50	404.01	t	5	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3276	120	26	2024-05-11	2	22.00	0.01	44.00	43.56	t	5	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3277	78	27	2024-05-11	2	85.00	0.07	170.00	158.10	t	5	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3278	64	16	2024-05-11	6	26.00	0.01	156.00	154.44	t	5	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3279	150	33	2024-05-11	7	21.00	0.03	147.00	142.59	t	5	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3280	34	48	2024-05-11	5	44.50	0.05	222.50	211.38	t	5	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3281	8	38	2024-05-12	4	39.00	0.06	156.00	146.64	t	6	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3282	85	19	2024-05-12	8	38.00	0.01	304.00	300.96	t	6	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3283	83	47	2024-05-12	8	82.50	0.03	660.00	640.20	t	6	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3284	144	33	2024-05-12	7	21.00	0.06	147.00	138.18	t	6	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3285	140	47	2024-05-12	1	82.50	0.05	82.50	78.38	t	6	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3286	102	51	2024-05-12	4	31.50	0.08	126.00	115.92	t	6	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3287	99	14	2024-05-12	3	12.00	0.09	36.00	32.76	t	6	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3288	112	26	2024-05-12	1	22.00	0.03	22.00	21.34	t	6	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3289	102	8	2024-05-12	6	40.00	0.06	240.00	225.60	t	6	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3290	98	26	2024-05-12	3	22.00	0.01	66.00	65.34	t	6	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3291	19	45	2024-05-12	6	59.50	0.01	357.00	353.43	t	6	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3292	36	47	2024-05-12	5	82.50	0.09	412.50	375.38	t	6	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3293	66	8	2024-05-12	1	40.00	0.01	40.00	39.60	t	6	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3294	119	4	2024-05-12	2	10.00	0.03	20.00	19.40	t	6	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3295	58	21	2024-05-12	4	34.00	0.02	136.00	133.28	t	6	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3296	65	7	2024-05-13	7	90.00	0.03	630.00	611.10	t	0	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3297	7	6	2024-05-13	3	25.00	0.01	75.00	74.25	t	0	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3298	62	4	2024-05-13	8	10.00	0.06	80.00	75.20	t	0	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3299	31	14	2024-05-13	4	12.00	0.03	48.00	46.56	t	0	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3300	15	28	2024-05-13	2	46.00	0.10	92.00	82.80	t	0	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3301	71	27	2024-05-13	9	85.00	0.05	765.00	726.75	t	0	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3302	6	46	2024-05-13	4	25.50	0.04	102.00	97.92	t	0	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3303	81	14	2024-05-13	3	12.00	0.09	36.00	32.76	t	0	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3304	14	2	2024-05-13	1	50.00	0.01	50.00	49.50	t	0	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3305	57	9	2024-05-13	2	36.00	0.09	72.00	65.52	t	0	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3306	19	36	2024-05-13	5	26.50	0.03	132.50	128.53	t	0	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3307	12	27	2024-05-13	2	85.00	0.08	170.00	156.40	t	0	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3308	21	53	2024-05-13	1	22.50	0.03	22.50	21.83	t	0	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3309	41	21	2024-05-13	5	34.00	0.02	170.00	166.60	t	0	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3310	129	23	2024-05-14	5	24.00	0.04	120.00	115.20	t	1	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3311	78	50	2024-05-14	5	17.50	0.06	87.50	82.25	t	1	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3312	113	41	2024-05-14	5	33.50	0.07	167.50	155.77	t	1	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3313	117	27	2024-05-14	9	85.00	0.08	765.00	703.80	t	1	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3314	143	38	2024-05-14	5	39.00	0.05	195.00	185.25	t	1	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3315	133	29	2024-05-14	9	40.00	0.03	360.00	349.20	t	1	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3316	135	39	2024-05-14	6	35.00	0.01	210.00	207.90	t	1	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3317	3	32	2024-05-14	2	48.00	0.04	96.00	92.16	t	1	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3318	84	28	2024-05-14	9	46.00	0.07	414.00	385.02	t	1	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3319	109	8	2024-05-14	8	40.00	0.01	320.00	316.80	t	1	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3320	56	51	2024-05-14	10	31.50	0.09	315.00	286.65	t	1	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3321	9	33	2024-05-14	7	21.00	0.09	147.00	133.77	t	1	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3322	37	47	2024-05-14	2	82.50	0.02	165.00	161.70	t	1	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3323	133	25	2024-05-14	8	65.00	0.08	520.00	478.40	t	1	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3324	113	3	2024-05-14	6	20.00	0.07	120.00	111.60	t	1	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3325	4	32	2024-05-14	6	48.00	0.09	288.00	262.08	t	1	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3326	141	26	2024-05-14	6	22.00	0.02	132.00	129.36	t	1	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3327	94	35	2024-05-14	5	63.00	0.02	315.00	308.70	t	1	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3328	88	16	2024-05-14	6	26.00	0.01	156.00	154.44	t	1	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3329	117	20	2024-05-14	3	17.00	0.01	51.00	50.49	t	1	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3330	108	35	2024-05-14	5	63.00	0.02	315.00	308.70	t	1	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3331	45	9	2024-05-14	5	36.00	0.01	180.00	178.20	t	1	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3332	16	32	2024-05-15	7	48.00	0.02	336.00	329.28	t	2	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3333	46	46	2024-05-15	3	25.50	0.01	76.50	75.74	t	2	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3334	58	18	2024-05-15	7	43.00	0.03	301.00	291.97	t	2	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3335	18	9	2024-05-15	9	36.00	0.01	324.00	320.76	t	2	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3336	95	37	2024-05-15	7	88.00	0.07	616.00	572.88	t	2	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3337	110	45	2024-05-15	2	59.50	0.05	119.00	113.05	t	2	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3338	95	34	2024-05-15	4	9.50	0.05	38.00	36.10	t	2	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3339	60	40	2024-05-15	8	13.00	0.02	104.00	101.92	t	2	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3340	88	27	2024-05-15	10	85.00	0.04	850.00	816.00	t	2	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3341	144	3	2024-05-15	1	20.00	0.00	20.00	20.00	f	2	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3342	92	2	2024-05-15	10	50.00	0.02	500.00	490.00	t	2	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3343	121	33	2024-05-16	1	21.00	0.04	21.00	20.16	t	3	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3344	109	52	2024-05-16	7	47.50	0.00	332.50	332.50	f	3	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3345	113	5	2024-05-16	6	60.00	0.09	360.00	327.60	t	3	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3346	146	15	2024-05-16	10	70.00	0.06	700.00	658.00	t	3	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3347	70	19	2024-05-16	5	38.00	0.01	190.00	188.10	t	3	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3348	96	32	2024-05-16	6	48.00	0.02	288.00	282.24	t	3	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3349	138	31	2024-05-16	4	37.00	0.06	148.00	139.12	t	3	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3350	32	10	2024-05-16	6	15.00	0.09	90.00	81.90	t	3	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3351	80	14	2024-05-16	9	12.00	0.01	108.00	106.92	t	3	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3352	79	24	2024-05-16	9	11.00	0.09	99.00	90.09	t	3	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3353	109	36	2024-05-16	7	26.50	0.08	185.50	170.66	t	3	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3354	19	48	2024-05-16	7	44.50	0.07	311.50	289.70	t	3	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3355	59	26	2024-05-16	4	22.00	0.07	88.00	81.84	t	3	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3356	15	17	2024-05-16	6	80.00	0.10	480.00	432.00	t	3	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3357	26	14	2024-05-16	5	12.00	0.03	60.00	58.20	t	3	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3358	2	29	2024-05-16	5	40.00	0.05	200.00	190.00	t	3	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3359	137	3	2024-05-16	6	20.00	0.02	120.00	117.60	t	3	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3360	118	21	2024-05-17	5	34.00	0.09	170.00	154.70	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3361	139	53	2024-05-17	7	22.50	0.07	157.50	146.48	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3362	129	33	2024-05-17	4	21.00	0.02	84.00	82.32	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3363	39	38	2024-05-17	10	39.00	0.00	390.00	390.00	f	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3364	19	46	2024-05-17	8	25.50	0.04	204.00	195.84	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3365	55	51	2024-05-17	2	31.50	0.01	63.00	62.37	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3366	9	19	2024-05-17	8	38.00	0.01	304.00	300.96	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3367	35	38	2024-05-17	4	39.00	0.02	156.00	152.88	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3368	150	20	2024-05-17	4	17.00	0.02	68.00	66.64	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3369	47	5	2024-05-17	5	60.00	0.04	300.00	288.00	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3370	8	18	2024-05-17	3	43.00	0.07	129.00	119.97	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3371	13	18	2024-05-17	2	43.00	0.05	86.00	81.70	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3372	143	12	2024-05-17	3	44.00	0.05	132.00	125.40	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3373	33	12	2024-05-17	9	44.00	0.02	396.00	388.08	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3374	147	33	2024-05-17	9	21.00	0.01	189.00	187.11	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3375	12	45	2024-05-17	4	59.50	0.01	238.00	235.62	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3376	134	24	2024-05-17	2	11.00	0.04	22.00	21.12	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3377	93	46	2024-05-17	6	25.50	0.05	153.00	145.35	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3378	2	37	2024-05-17	7	88.00	0.00	616.00	616.00	f	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3379	20	8	2024-05-17	8	40.00	0.10	320.00	288.00	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3380	10	18	2024-05-17	2	43.00	0.01	86.00	85.14	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3381	23	39	2024-05-18	10	35.00	0.05	350.00	332.50	t	5	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3382	63	21	2024-05-18	9	34.00	0.08	306.00	281.52	t	5	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3383	22	41	2024-05-18	10	33.50	0.05	335.00	318.25	t	5	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3384	89	5	2024-05-18	2	60.00	0.04	120.00	115.20	t	5	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3385	84	27	2024-05-18	7	85.00	0.04	595.00	571.20	t	5	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3386	114	21	2024-05-18	7	34.00	0.01	238.00	235.62	t	5	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3387	145	45	2024-05-18	4	59.50	0.01	238.00	235.62	t	5	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3388	69	44	2024-05-18	1	10.50	0.01	10.50	10.40	t	5	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3389	37	9	2024-05-18	1	36.00	0.06	36.00	33.84	t	5	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3390	48	26	2024-05-18	8	22.00	0.09	176.00	160.16	t	5	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3391	97	6	2024-05-18	9	25.00	0.05	225.00	213.75	t	5	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3392	116	53	2024-05-18	9	22.50	0.01	202.50	200.48	t	5	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3393	26	35	2024-05-18	8	63.00	0.09	504.00	458.64	t	5	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3394	88	42	2024-05-18	1	53.00	0.03	53.00	51.41	t	5	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3395	91	49	2024-05-18	9	39.50	0.06	355.50	334.17	t	5	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3396	32	33	2024-05-18	5	21.00	0.08	105.00	96.60	t	5	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3397	150	49	2024-05-18	6	39.50	0.07	237.00	220.41	t	5	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3398	12	23	2024-05-18	5	24.00	0.05	120.00	114.00	t	5	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3399	149	25	2024-05-18	6	65.00	0.06	390.00	366.60	t	5	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3400	66	32	2024-05-18	3	48.00	0.05	144.00	136.80	t	5	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3401	114	17	2024-05-18	9	80.00	0.04	720.00	691.20	t	5	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3402	86	38	2024-05-18	1	39.00	0.00	39.00	39.00	f	5	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3403	43	1	2024-05-18	8	30.00	0.06	240.00	225.60	t	5	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3404	135	10	2024-05-19	9	15.00	0.08	135.00	124.20	t	6	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3405	32	28	2024-05-19	8	46.00	0.07	368.00	342.24	t	6	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3406	143	9	2024-05-19	10	36.00	0.00	360.00	360.00	f	6	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3407	63	38	2024-05-19	3	39.00	0.04	117.00	112.32	t	6	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3408	37	1	2024-05-19	2	30.00	0.00	60.00	60.00	f	6	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3409	73	53	2024-05-19	1	22.50	0.02	22.50	22.05	t	6	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3410	135	42	2024-05-19	7	53.00	0.02	371.00	363.58	t	6	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3411	38	35	2024-05-19	3	63.00	0.09	189.00	171.99	t	6	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3412	101	19	2024-05-19	10	38.00	0.06	380.00	357.20	t	6	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3413	112	7	2024-05-20	10	90.00	0.04	900.00	864.00	t	0	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3414	20	36	2024-05-20	2	26.50	0.09	53.00	48.23	t	0	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3415	70	49	2024-05-20	3	39.50	0.06	118.50	111.39	t	0	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3416	109	44	2024-05-20	7	10.50	0.08	73.50	67.62	t	0	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3417	71	33	2024-05-20	3	21.00	0.01	63.00	62.37	t	0	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3418	96	8	2024-05-20	3	40.00	0.09	120.00	109.20	t	0	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3419	33	10	2024-05-20	8	15.00	0.02	120.00	117.60	t	0	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3420	34	23	2024-05-20	1	24.00	0.02	24.00	23.52	t	0	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3421	30	44	2024-05-20	9	10.50	0.02	94.50	92.61	t	0	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3422	121	24	2024-05-20	4	11.00	0.09	44.00	40.04	t	0	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3423	146	32	2024-05-20	3	48.00	0.03	144.00	139.68	t	0	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3424	68	21	2024-05-20	4	34.00	0.09	136.00	123.76	t	0	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3425	58	46	2024-05-20	1	25.50	0.00	25.50	25.50	f	0	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3426	57	26	2024-05-20	6	22.00	0.07	132.00	122.76	t	0	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3427	133	5	2024-05-20	2	60.00	0.04	120.00	115.20	t	0	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3428	70	38	2024-05-20	6	39.00	0.05	234.00	222.30	t	0	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3429	47	53	2024-05-21	8	22.50	0.08	180.00	165.60	t	1	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3430	57	12	2024-05-21	3	44.00	0.09	132.00	120.12	t	1	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3431	49	40	2024-05-21	5	13.00	0.04	65.00	62.40	t	1	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3432	127	6	2024-05-21	2	25.00	0.06	50.00	47.00	t	1	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3433	101	30	2024-05-21	3	18.00	0.05	54.00	51.30	t	1	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3434	44	48	2024-05-21	7	44.50	0.06	311.50	292.81	t	1	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3435	142	30	2024-05-21	1	18.00	0.09	18.00	16.38	t	1	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3436	79	37	2024-05-21	6	88.00	0.08	528.00	485.76	t	1	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3437	140	9	2024-05-21	7	36.00	0.01	252.00	249.48	t	1	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3438	91	31	2024-05-21	1	37.00	0.01	37.00	36.63	t	1	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3439	98	21	2024-05-21	6	34.00	0.09	204.00	185.64	t	1	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3440	64	42	2024-05-21	2	53.00	0.05	106.00	100.70	t	1	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3441	76	27	2024-05-21	4	85.00	0.05	340.00	323.00	t	1	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3442	119	45	2024-05-21	5	59.50	0.09	297.50	270.73	t	1	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3443	11	26	2024-05-22	3	22.00	0.02	66.00	64.68	t	2	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3444	58	21	2024-05-22	8	34.00	0.06	272.00	255.68	t	2	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3445	128	18	2024-05-22	6	43.00	0.10	258.00	232.20	t	2	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3446	77	29	2024-05-22	1	40.00	0.03	40.00	38.80	t	2	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3447	141	43	2024-05-22	1	28.00	0.06	28.00	26.32	t	2	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3448	3	6	2024-05-22	8	25.00	0.01	200.00	198.00	t	2	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3449	71	17	2024-05-22	5	80.00	0.01	400.00	396.00	t	2	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3450	91	16	2024-05-22	1	26.00	0.08	26.00	23.92	t	2	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3451	85	29	2024-05-22	4	40.00	0.04	160.00	153.60	t	2	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3452	35	27	2024-05-22	4	85.00	0.05	340.00	323.00	t	2	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3453	80	7	2024-05-22	3	90.00	0.09	270.00	245.70	t	2	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3454	75	34	2024-05-23	10	9.50	0.04	95.00	91.20	t	3	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3455	120	20	2024-05-23	2	17.00	0.04	34.00	32.64	t	3	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3456	38	51	2024-05-23	8	31.50	0.09	252.00	229.32	t	3	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3457	50	34	2024-05-23	10	9.50	0.01	95.00	94.05	t	3	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3458	25	28	2024-05-23	10	46.00	0.00	460.00	460.00	f	3	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3459	139	44	2024-05-23	5	10.50	0.01	52.50	51.98	t	3	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3460	107	40	2024-05-23	10	13.00	0.08	130.00	119.60	t	3	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3461	37	18	2024-05-23	4	43.00	0.01	172.00	170.28	t	3	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3462	106	45	2024-05-23	10	59.50	0.07	595.00	553.35	t	3	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3463	125	10	2024-05-23	3	15.00	0.03	45.00	43.65	t	3	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3464	66	23	2024-05-23	7	24.00	0.02	168.00	164.64	t	3	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3465	12	35	2024-05-23	4	63.00	0.08	252.00	231.84	t	3	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3466	140	21	2024-05-23	7	34.00	0.09	238.00	216.58	t	3	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3467	133	40	2024-05-23	6	13.00	0.08	78.00	71.76	t	3	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3468	12	5	2024-05-23	5	60.00	0.01	300.00	297.00	t	3	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3469	35	18	2024-05-24	10	43.00	0.05	430.00	408.50	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3470	94	38	2024-05-24	4	39.00	0.08	156.00	143.52	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3471	77	6	2024-05-24	5	25.00	0.03	125.00	121.25	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3472	91	52	2024-05-24	8	47.50	0.02	380.00	372.40	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3473	53	14	2024-05-24	2	12.00	0.09	24.00	21.84	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3474	62	19	2024-05-24	8	38.00	0.09	304.00	276.64	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3475	30	50	2024-05-24	4	17.50	0.08	70.00	64.40	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3476	85	19	2024-05-24	8	38.00	0.06	304.00	285.76	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3477	14	9	2024-05-24	3	36.00	0.08	108.00	99.36	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3478	144	33	2024-05-24	5	21.00	0.07	105.00	97.65	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3479	97	2	2024-05-24	2	50.00	0.03	100.00	97.00	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3480	98	18	2024-05-24	7	43.00	0.09	301.00	273.91	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3481	62	19	2024-05-24	10	38.00	0.07	380.00	353.40	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3482	92	53	2024-05-24	8	22.50	0.06	180.00	169.20	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3483	36	18	2024-05-24	1	43.00	0.09	43.00	39.13	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3484	92	34	2024-05-25	3	9.50	0.03	28.50	27.65	t	5	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3485	93	11	2024-05-25	8	32.00	0.07	256.00	238.08	t	5	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3486	145	4	2024-05-25	3	10.00	0.05	30.00	28.50	t	5	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3487	78	53	2024-05-25	6	22.50	0.03	135.00	130.95	t	5	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3488	13	29	2024-05-25	9	40.00	0.02	360.00	352.80	t	5	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3489	7	9	2024-05-25	2	36.00	0.00	72.00	72.00	f	5	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3490	54	33	2024-05-25	8	21.00	0.09	168.00	152.88	t	5	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3491	128	28	2024-05-25	5	46.00	0.02	230.00	225.40	t	5	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3492	34	50	2024-05-25	2	17.50	0.08	35.00	32.20	t	5	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3493	144	49	2024-05-25	1	39.50	0.07	39.50	36.74	t	5	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3494	41	2	2024-05-26	6	50.00	0.04	300.00	288.00	t	6	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3495	136	15	2024-05-26	7	70.00	0.01	490.00	485.10	t	6	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3496	137	25	2024-05-26	10	65.00	0.08	650.00	598.00	t	6	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3497	9	52	2024-05-26	4	47.50	0.10	190.00	171.00	t	6	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3498	82	23	2024-05-26	9	24.00	0.03	216.00	209.52	t	6	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3499	36	26	2024-05-26	4	22.00	0.02	88.00	86.24	t	6	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3500	77	7	2024-05-26	2	90.00	0.05	180.00	171.00	t	6	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3501	133	46	2024-05-26	7	25.50	0.04	178.50	171.36	t	6	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3502	16	15	2024-05-26	10	70.00	0.04	700.00	672.00	t	6	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3503	68	35	2024-05-26	6	63.00	0.05	378.00	359.10	t	6	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3504	52	47	2024-05-26	6	82.50	0.04	495.00	475.20	t	6	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3505	119	29	2024-05-26	1	40.00	0.08	40.00	36.80	t	6	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3506	23	50	2024-05-27	1	17.50	0.07	17.50	16.28	t	0	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3507	78	33	2024-05-27	3	21.00	0.02	63.00	61.74	t	0	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3508	30	2	2024-05-27	10	50.00	0.08	500.00	460.00	t	0	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3509	150	31	2024-05-27	7	37.00	0.02	259.00	253.82	t	0	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3510	35	50	2024-05-27	7	17.50	0.05	122.50	116.38	t	0	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3511	27	15	2024-05-27	2	70.00	0.09	140.00	127.40	t	0	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3512	130	15	2024-05-27	7	70.00	0.06	490.00	460.60	t	0	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3513	77	22	2024-05-27	2	54.00	0.01	108.00	106.92	t	0	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3514	136	26	2024-05-27	3	22.00	0.09	66.00	60.06	t	0	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3515	16	44	2024-05-27	5	10.50	0.07	52.50	48.82	t	0	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3516	57	26	2024-05-27	8	22.00	0.06	176.00	165.44	t	0	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3517	91	11	2024-05-27	2	32.00	0.02	64.00	62.72	t	0	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3518	68	22	2024-05-27	7	54.00	0.04	378.00	362.88	t	0	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3519	27	52	2024-05-27	4	47.50	0.03	190.00	184.30	t	0	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3520	6	25	2024-05-27	8	65.00	0.04	520.00	499.20	t	0	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3521	15	7	2024-05-27	1	90.00	0.04	90.00	86.40	t	0	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3522	47	20	2024-05-27	3	17.00	0.07	51.00	47.43	t	0	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3523	95	39	2024-05-27	5	35.00	0.01	175.00	173.25	t	0	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3524	49	47	2024-05-27	10	82.50	0.07	825.00	767.25	t	0	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3525	108	41	2024-05-27	4	33.50	0.05	134.00	127.30	t	0	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3526	39	39	2024-05-27	9	35.00	0.04	315.00	302.40	t	0	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3527	10	32	2024-05-28	4	48.00	0.08	192.00	176.64	t	1	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3528	51	40	2024-05-28	8	13.00	0.06	104.00	97.76	t	1	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3529	52	11	2024-05-28	1	32.00	0.02	32.00	31.36	t	1	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3530	72	4	2024-05-28	5	10.00	0.08	50.00	46.00	t	1	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3531	28	9	2024-05-28	7	36.00	0.10	252.00	226.80	t	1	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3532	15	26	2024-05-28	3	22.00	0.01	66.00	65.34	t	1	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3533	65	12	2024-05-28	5	44.00	0.04	220.00	211.20	t	1	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3534	134	39	2024-05-28	2	35.00	0.08	70.00	64.40	t	1	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3535	32	1	2024-05-28	9	30.00	0.01	270.00	267.30	t	1	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3536	136	11	2024-05-28	3	32.00	0.01	96.00	95.04	t	1	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3537	63	15	2024-05-28	7	70.00	0.01	490.00	485.10	t	1	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3538	6	47	2024-05-28	10	82.50	0.05	825.00	783.75	t	1	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3539	44	1	2024-05-28	10	30.00	0.00	300.00	300.00	f	1	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3540	62	25	2024-05-28	2	65.00	0.09	130.00	118.30	t	1	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3541	33	51	2024-05-29	3	31.50	0.01	94.50	93.55	t	2	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3542	55	51	2024-05-29	2	31.50	0.05	63.00	59.85	t	2	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3543	122	37	2024-05-29	10	88.00	0.09	880.00	800.80	t	2	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3544	48	52	2024-05-29	3	47.50	0.03	142.50	138.23	t	2	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3545	32	5	2024-05-29	6	60.00	0.02	360.00	352.80	t	2	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3546	47	15	2024-05-29	10	70.00	0.02	700.00	686.00	t	2	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3547	109	3	2024-05-29	8	20.00	0.04	160.00	153.60	t	2	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3548	38	34	2024-05-29	9	9.50	0.09	85.50	77.81	t	2	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3549	71	50	2024-05-29	7	17.50	0.06	122.50	115.15	t	2	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3550	88	34	2024-05-29	2	9.50	0.10	19.00	17.10	t	2	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3551	100	7	2024-05-29	4	90.00	0.08	360.00	331.20	t	2	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3552	127	35	2024-05-29	2	63.00	0.00	126.00	126.00	f	2	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3553	40	48	2024-05-29	6	44.50	0.05	267.00	253.65	t	2	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3554	105	40	2024-05-29	8	13.00	0.07	104.00	96.72	t	2	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3555	133	50	2024-05-29	2	17.50	0.09	35.00	31.85	t	2	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3556	121	21	2024-05-29	6	34.00	0.04	204.00	195.84	t	2	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3557	49	34	2024-05-29	5	9.50	0.01	47.50	47.03	t	2	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3558	29	51	2024-05-29	7	31.50	0.07	220.50	205.07	t	2	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3559	143	32	2024-05-29	10	48.00	0.01	480.00	475.20	t	2	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3560	64	47	2024-05-29	8	82.50	0.04	660.00	633.60	t	2	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3561	30	26	2024-05-30	6	22.00	0.05	132.00	125.40	t	3	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3562	28	6	2024-05-30	5	25.00	0.10	125.00	112.50	t	3	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3563	61	37	2024-05-30	3	88.00	0.09	264.00	240.24	t	3	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3564	137	19	2024-05-30	4	38.00	0.03	152.00	147.44	t	3	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3565	142	49	2024-05-30	4	39.50	0.07	158.00	146.94	t	3	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3566	5	1	2024-05-30	3	30.00	0.06	90.00	84.60	t	3	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3567	36	11	2024-05-30	3	32.00	0.02	96.00	94.08	t	3	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3568	22	36	2024-05-30	10	26.50	0.02	265.00	259.70	t	3	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3569	2	13	2024-05-30	9	23.00	0.07	207.00	192.51	t	3	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3570	97	36	2024-05-30	6	26.50	0.01	159.00	157.41	t	3	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3571	124	22	2024-05-30	4	54.00	0.01	216.00	213.84	t	3	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3572	78	14	2024-05-30	3	12.00	0.08	36.00	33.12	t	3	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3573	68	50	2024-05-30	6	17.50	0.05	105.00	99.75	t	3	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3574	96	39	2024-05-30	10	35.00	0.09	350.00	318.50	t	3	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3575	86	37	2024-05-30	8	88.00	0.03	704.00	682.88	t	3	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3576	62	6	2024-05-30	10	25.00	0.07	250.00	232.50	t	3	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3577	144	27	2024-05-30	6	85.00	0.00	510.00	510.00	f	3	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3578	111	19	2024-05-30	5	38.00	0.01	190.00	188.10	t	3	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3579	85	16	2024-05-30	6	26.00	0.02	156.00	152.88	t	3	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3580	143	28	2024-05-30	4	46.00	0.08	184.00	169.28	t	3	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3581	120	28	2024-05-31	3	46.00	0.07	138.00	128.34	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3582	51	30	2024-05-31	10	18.00	0.09	180.00	163.80	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3583	128	33	2024-05-31	9	21.00	0.03	189.00	183.33	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3584	91	41	2024-05-31	3	33.50	0.02	100.50	98.49	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3585	87	2	2024-05-31	6	50.00	0.09	300.00	273.00	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3586	58	13	2024-05-31	8	23.00	0.00	184.00	184.00	f	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3587	116	9	2024-05-31	7	36.00	0.05	252.00	239.40	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3588	99	4	2024-05-31	4	10.00	0.03	40.00	38.80	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3589	116	6	2024-05-31	1	25.00	0.06	25.00	23.50	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3590	133	43	2024-05-31	9	28.00	0.01	252.00	249.48	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3591	56	37	2024-05-31	2	88.00	0.00	176.00	176.00	f	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3592	61	18	2024-05-31	5	43.00	0.07	215.00	199.95	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3593	62	40	2024-05-31	9	13.00	0.07	117.00	108.81	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3594	12	51	2024-05-31	9	31.50	0.09	283.50	257.99	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3595	75	46	2024-05-31	10	25.50	0.04	255.00	244.80	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3596	83	8	2024-05-31	1	40.00	0.09	40.00	36.40	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3597	24	23	2024-05-31	10	24.00	0.01	240.00	237.60	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3598	112	7	2024-05-31	2	90.00	0.08	180.00	165.60	t	4	5	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3599	78	34	2024-06-01	7	9.50	0.08	66.50	61.18	t	5	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3600	101	17	2024-06-01	6	80.00	0.00	480.00	480.00	f	5	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3601	47	22	2024-06-01	2	54.00	0.06	108.00	101.52	t	5	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3602	13	44	2024-06-01	4	10.50	0.02	42.00	41.16	t	5	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3603	132	3	2024-06-01	9	20.00	0.05	180.00	171.00	t	5	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3604	93	27	2024-06-01	2	85.00	0.03	170.00	164.90	t	5	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3605	72	14	2024-06-01	5	12.00	0.09	60.00	54.60	t	5	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3606	42	51	2024-06-01	3	31.50	0.07	94.50	87.88	t	5	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3607	1	28	2024-06-01	6	46.00	0.08	276.00	253.92	t	5	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3608	13	30	2024-06-01	4	18.00	0.08	72.00	66.24	t	5	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3609	116	24	2024-06-01	2	11.00	0.05	22.00	20.90	t	5	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3610	139	20	2024-06-01	1	17.00	0.04	17.00	16.32	t	5	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3611	129	26	2024-06-01	4	22.00	0.03	88.00	85.36	t	5	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3612	92	31	2024-06-01	9	37.00	0.05	333.00	316.35	t	5	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3613	134	19	2024-06-02	3	38.00	0.04	114.00	109.44	t	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3614	43	32	2024-06-02	7	48.00	0.04	336.00	322.56	t	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3615	114	46	2024-06-02	3	25.50	0.04	76.50	73.44	t	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3616	18	10	2024-06-02	5	15.00	0.09	75.00	68.25	t	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3617	96	19	2024-06-02	9	38.00	0.06	342.00	321.48	t	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3618	81	39	2024-06-02	7	35.00	0.00	245.00	245.00	f	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3619	38	53	2024-06-02	3	22.50	0.02	67.50	66.15	t	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3620	63	33	2024-06-02	5	21.00	0.08	105.00	96.60	t	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3621	36	30	2024-06-02	2	18.00	0.06	36.00	33.84	t	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3622	132	43	2024-06-02	3	28.00	0.04	84.00	80.64	t	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3623	16	11	2024-06-02	8	32.00	0.04	256.00	245.76	t	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3624	92	45	2024-06-02	1	59.50	0.08	59.50	54.74	t	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3625	110	28	2024-06-02	9	46.00	0.00	414.00	414.00	f	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3626	10	12	2024-06-02	2	44.00	0.04	88.00	84.48	t	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3627	1	29	2024-06-02	4	40.00	0.05	160.00	152.00	t	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3628	96	39	2024-06-03	6	35.00	0.07	210.00	195.30	t	0	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3629	70	12	2024-06-03	4	44.00	0.01	176.00	174.24	t	0	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3630	52	45	2024-06-03	2	59.50	0.04	119.00	114.24	t	0	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3631	26	22	2024-06-03	1	54.00	0.07	54.00	50.22	t	0	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3632	60	15	2024-06-03	10	70.00	0.04	700.00	672.00	t	0	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3633	21	14	2024-06-03	2	12.00	0.01	24.00	23.76	t	0	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3634	59	41	2024-06-03	2	33.50	0.08	67.00	61.64	t	0	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3635	69	7	2024-06-03	2	90.00	0.02	180.00	176.40	t	0	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3636	43	37	2024-06-03	2	88.00	0.06	176.00	165.44	t	0	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3637	110	7	2024-06-03	2	90.00	0.02	180.00	176.40	t	0	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3638	64	19	2024-06-03	6	38.00	0.04	228.00	218.88	t	0	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3639	57	14	2024-06-03	1	12.00	0.03	12.00	11.64	t	0	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3640	107	24	2024-06-03	9	11.00	0.09	99.00	90.09	t	0	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3641	58	7	2024-06-03	5	90.00	0.00	450.00	450.00	f	0	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3642	118	53	2024-06-03	9	22.50	0.01	202.50	200.48	t	0	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3643	116	37	2024-06-03	3	88.00	0.02	264.00	258.72	t	0	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3644	110	50	2024-06-03	8	17.50	0.02	140.00	137.20	t	0	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3645	36	2	2024-06-03	4	50.00	0.05	200.00	190.00	t	0	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3646	106	48	2024-06-03	10	44.50	0.08	445.00	409.40	t	0	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3647	17	32	2024-06-03	4	48.00	0.05	192.00	182.40	t	0	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3648	124	40	2024-06-04	7	13.00	0.01	91.00	90.09	t	1	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3649	101	15	2024-06-04	8	70.00	0.06	560.00	526.40	t	1	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3650	64	45	2024-06-04	5	59.50	0.09	297.50	270.73	t	1	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3651	75	47	2024-06-04	5	82.50	0.10	412.50	371.25	t	1	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3652	17	43	2024-06-04	3	28.00	0.05	84.00	79.80	t	1	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3653	37	2	2024-06-04	10	50.00	0.10	500.00	450.00	t	1	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3654	37	28	2024-06-04	3	46.00	0.07	138.00	128.34	t	1	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3655	26	3	2024-06-04	7	20.00	0.05	140.00	133.00	t	1	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3656	116	4	2024-06-04	8	10.00	0.06	80.00	75.20	t	1	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3657	18	1	2024-06-04	1	30.00	0.06	30.00	28.20	t	1	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3658	22	38	2024-06-04	3	39.00	0.06	117.00	109.98	t	1	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3659	115	15	2024-06-04	10	70.00	0.02	700.00	686.00	t	1	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3660	41	1	2024-06-04	4	30.00	0.01	120.00	118.80	t	1	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3661	87	10	2024-06-04	2	15.00	0.05	30.00	28.50	t	1	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3662	7	10	2024-06-04	3	15.00	0.01	45.00	44.55	t	1	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3663	105	11	2024-06-05	2	32.00	0.03	64.00	62.08	t	2	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3664	31	23	2024-06-05	8	24.00	0.02	192.00	188.16	t	2	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3665	137	6	2024-06-05	9	25.00	0.05	225.00	213.75	t	2	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3666	119	19	2024-06-05	3	38.00	0.05	114.00	108.30	t	2	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3667	127	38	2024-06-05	7	39.00	0.08	273.00	251.16	t	2	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3668	10	11	2024-06-05	4	32.00	0.05	128.00	121.60	t	2	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3669	125	32	2024-06-05	6	48.00	0.04	288.00	276.48	t	2	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3670	72	5	2024-06-05	6	60.00	0.06	360.00	338.40	t	2	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3671	126	33	2024-06-05	5	21.00	0.01	105.00	103.95	t	2	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3672	15	30	2024-06-05	4	18.00	0.03	72.00	69.84	t	2	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3673	4	3	2024-06-05	9	20.00	0.05	180.00	171.00	t	2	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3674	92	6	2024-06-05	8	25.00	0.07	200.00	186.00	t	2	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3675	116	28	2024-06-05	10	46.00	0.08	460.00	423.20	t	2	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3676	91	24	2024-06-05	1	11.00	0.01	11.00	10.89	t	2	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3677	46	15	2024-06-05	8	70.00	0.02	560.00	548.80	t	2	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3678	100	17	2024-06-05	1	80.00	0.03	80.00	77.60	t	2	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3679	47	18	2024-06-05	6	43.00	0.07	258.00	239.94	t	2	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3680	131	20	2024-06-06	9	17.00	0.07	153.00	142.29	t	3	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3681	120	51	2024-06-06	6	31.50	0.00	189.00	189.00	f	3	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3682	70	5	2024-06-06	1	60.00	0.05	60.00	57.00	t	3	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3683	119	6	2024-06-06	6	25.00	0.09	150.00	136.50	t	3	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3684	143	36	2024-06-06	8	26.50	0.01	212.00	209.88	t	3	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3685	36	31	2024-06-06	2	37.00	0.00	74.00	74.00	f	3	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3686	57	39	2024-06-06	5	35.00	0.10	175.00	157.50	t	3	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3687	23	12	2024-06-06	4	44.00	0.01	176.00	174.24	t	3	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3688	71	50	2024-06-06	3	17.50	0.02	52.50	51.45	t	3	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3689	127	31	2024-06-06	5	37.00	0.01	185.00	183.15	t	3	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3690	76	46	2024-06-06	4	25.50	0.03	102.00	98.94	t	3	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3691	10	29	2024-06-06	9	40.00	0.08	360.00	331.20	t	3	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3692	125	39	2024-06-06	4	35.00	0.09	140.00	127.40	t	3	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3693	48	27	2024-06-06	3	85.00	0.10	255.00	229.50	t	3	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3694	20	9	2024-06-06	5	36.00	0.01	180.00	178.20	t	3	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3695	98	4	2024-06-06	6	10.00	0.04	60.00	57.60	t	3	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3696	127	28	2024-06-06	9	46.00	0.09	414.00	376.74	t	3	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3697	9	33	2024-06-06	10	21.00	0.00	210.00	210.00	f	3	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3698	126	4	2024-06-06	1	10.00	0.01	10.00	9.90	t	3	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3699	132	2	2024-06-06	9	50.00	0.09	450.00	409.50	t	3	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3700	130	3	2024-06-06	7	20.00	0.03	140.00	135.80	t	3	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3701	39	23	2024-06-07	7	24.00	0.09	168.00	152.88	t	4	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3702	137	18	2024-06-07	7	43.00	0.08	301.00	276.92	t	4	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3703	67	19	2024-06-07	9	38.00	0.10	342.00	307.80	t	4	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3704	117	22	2024-06-07	6	54.00	0.01	324.00	320.76	t	4	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3705	20	53	2024-06-07	8	22.50	0.09	180.00	163.80	t	4	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3706	128	39	2024-06-07	4	35.00	0.02	140.00	137.20	t	4	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3707	146	24	2024-06-07	3	11.00	0.01	33.00	32.67	t	4	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3708	7	28	2024-06-07	10	46.00	0.04	460.00	441.60	t	4	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3709	110	33	2024-06-07	5	21.00	0.09	105.00	95.55	t	4	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3710	86	24	2024-06-07	3	11.00	0.09	33.00	30.03	t	4	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3711	29	9	2024-06-07	9	36.00	0.03	324.00	314.28	t	4	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3712	78	41	2024-06-07	6	33.50	0.03	201.00	194.97	t	4	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3713	89	13	2024-06-07	10	23.00	0.02	230.00	225.40	t	4	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3714	65	1	2024-06-07	6	30.00	0.04	180.00	172.80	t	4	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3715	111	17	2024-06-07	9	80.00	0.00	720.00	720.00	f	4	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3716	81	38	2024-06-07	10	39.00	0.09	390.00	354.90	t	4	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3717	2	15	2024-06-08	2	70.00	0.04	140.00	134.40	t	5	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3718	123	37	2024-06-08	3	88.00	0.06	264.00	248.16	t	5	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3719	27	1	2024-06-08	8	30.00	0.08	240.00	220.80	t	5	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3720	84	30	2024-06-08	5	18.00	0.07	90.00	83.70	t	5	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3721	95	33	2024-06-08	5	21.00	0.03	105.00	101.85	t	5	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3722	77	25	2024-06-08	6	65.00	0.02	390.00	382.20	t	5	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3723	67	38	2024-06-08	1	39.00	0.05	39.00	37.05	t	5	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3724	1	28	2024-06-08	9	46.00	0.07	414.00	385.02	t	5	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3725	14	13	2024-06-08	8	23.00	0.06	184.00	172.96	t	5	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3726	51	14	2024-06-08	4	12.00	0.08	48.00	44.16	t	5	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3727	80	20	2024-06-08	2	17.00	0.03	34.00	32.98	t	5	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3728	21	27	2024-06-08	3	85.00	0.09	255.00	232.05	t	5	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3729	109	22	2024-06-09	9	54.00	0.04	486.00	466.56	t	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3730	4	21	2024-06-09	10	34.00	0.02	340.00	333.20	t	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3731	57	50	2024-06-09	10	17.50	0.09	175.00	159.25	t	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3732	20	10	2024-06-09	6	15.00	0.04	90.00	86.40	t	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3733	125	15	2024-06-09	6	70.00	0.02	420.00	411.60	t	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3734	9	17	2024-06-09	8	80.00	0.05	640.00	608.00	t	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3735	61	34	2024-06-09	10	9.50	0.10	95.00	85.50	t	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3736	75	19	2024-06-09	9	38.00	0.02	342.00	335.16	t	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3737	79	4	2024-06-09	1	10.00	0.07	10.00	9.30	t	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3738	31	28	2024-06-09	10	46.00	0.03	460.00	446.20	t	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3739	115	8	2024-06-09	6	40.00	0.04	240.00	230.40	t	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3740	91	26	2024-06-09	5	22.00	0.02	110.00	107.80	t	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3741	79	31	2024-06-09	5	37.00	0.05	185.00	175.75	t	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3742	111	22	2024-06-09	7	54.00	0.08	378.00	347.76	t	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3743	58	17	2024-06-09	7	80.00	0.07	560.00	520.80	t	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3744	78	35	2024-06-09	2	63.00	0.09	126.00	114.66	t	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3745	66	24	2024-06-09	3	11.00	0.08	33.00	30.36	t	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3746	51	24	2024-06-09	4	11.00	0.09	44.00	40.04	t	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3747	27	22	2024-06-09	6	54.00	0.08	324.00	298.08	t	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3748	88	45	2024-06-09	9	59.50	0.08	535.50	492.66	t	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3749	107	46	2024-06-09	5	25.50	0.09	127.50	116.03	t	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3750	93	41	2024-06-10	9	33.50	0.09	301.50	274.37	t	0	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3751	68	27	2024-06-10	4	85.00	0.05	340.00	323.00	t	0	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3752	98	51	2024-06-10	7	31.50	0.04	220.50	211.68	t	0	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3753	64	52	2024-06-10	2	47.50	0.04	95.00	91.20	t	0	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3754	22	36	2024-06-10	6	26.50	0.04	159.00	152.64	t	0	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3755	114	33	2024-06-10	10	21.00	0.07	210.00	195.30	t	0	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3756	135	27	2024-06-10	1	85.00	0.00	85.00	85.00	f	0	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3757	104	23	2024-06-10	3	24.00	0.08	72.00	66.24	t	0	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3758	89	17	2024-06-10	5	80.00	0.06	400.00	376.00	t	0	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3759	87	25	2024-06-10	6	65.00	0.05	390.00	370.50	t	0	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3760	73	36	2024-06-11	7	26.50	0.03	185.50	179.94	t	1	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3761	57	20	2024-06-11	7	17.00	0.04	119.00	114.24	t	1	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3762	128	44	2024-06-11	3	10.50	0.02	31.50	30.87	t	1	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3763	123	48	2024-06-11	2	44.50	0.04	89.00	85.44	t	1	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3764	145	42	2024-06-11	3	53.00	0.04	159.00	152.64	t	1	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3765	88	1	2024-06-11	10	30.00	0.06	300.00	282.00	t	1	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3766	107	32	2024-06-11	5	48.00	0.06	240.00	225.60	t	1	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3767	76	4	2024-06-11	9	10.00	0.01	90.00	89.10	t	1	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3768	136	19	2024-06-11	6	38.00	0.03	228.00	221.16	t	1	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3769	48	46	2024-06-11	2	25.50	0.08	51.00	46.92	t	1	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3770	73	48	2024-06-11	1	44.50	0.09	44.50	40.50	t	1	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3771	80	26	2024-06-11	5	22.00	0.08	110.00	101.20	t	1	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3772	123	6	2024-06-11	6	25.00	0.03	150.00	145.50	t	1	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3773	12	41	2024-06-11	7	33.50	0.06	234.50	220.43	t	1	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3774	148	42	2024-06-11	3	53.00	0.03	159.00	154.23	t	1	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3775	80	9	2024-06-11	6	36.00	0.09	216.00	196.56	t	1	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3776	75	4	2024-06-11	8	10.00	0.02	80.00	78.40	t	1	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3777	96	29	2024-06-11	6	40.00	0.07	240.00	223.20	t	1	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3778	105	52	2024-06-11	8	47.50	0.09	380.00	345.80	t	1	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3779	137	11	2024-06-11	3	32.00	0.02	96.00	94.08	t	1	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3780	28	16	2024-06-11	10	26.00	0.04	260.00	249.60	t	1	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3781	34	37	2024-06-11	3	88.00	0.06	264.00	248.16	t	1	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3782	48	45	2024-06-12	8	59.50	0.04	476.00	456.96	t	2	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3783	2	27	2024-06-12	5	85.00	0.05	425.00	403.75	t	2	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3784	12	31	2024-06-12	1	37.00	0.07	37.00	34.41	t	2	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3785	58	26	2024-06-12	1	22.00	0.03	22.00	21.34	t	2	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3786	116	25	2024-06-12	1	65.00	0.07	65.00	60.45	t	2	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3787	23	34	2024-06-12	9	9.50	0.01	85.50	84.65	t	2	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3788	130	48	2024-06-12	7	44.50	0.05	311.50	295.93	t	2	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3789	65	28	2024-06-12	5	46.00	0.05	230.00	218.50	t	2	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3790	39	18	2024-06-12	7	43.00	0.05	301.00	285.95	t	2	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3791	42	46	2024-06-12	9	25.50	0.05	229.50	218.02	t	2	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3792	89	44	2024-06-12	1	10.50	0.06	10.50	9.87	t	2	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3793	66	15	2024-06-12	10	70.00	0.09	700.00	637.00	t	2	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3794	129	53	2024-06-12	10	22.50	0.00	225.00	225.00	f	2	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3795	111	46	2024-06-12	3	25.50	0.08	76.50	70.38	t	2	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3796	56	39	2024-06-12	4	35.00	0.04	140.00	134.40	t	2	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3797	129	33	2024-06-12	3	21.00	0.05	63.00	59.85	t	2	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3798	68	47	2024-06-12	10	82.50	0.01	825.00	816.75	t	2	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3799	70	37	2024-06-12	5	88.00	0.04	440.00	422.40	t	2	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3800	63	44	2024-06-12	5	10.50	0.01	52.50	51.98	t	2	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3801	100	37	2024-06-13	8	88.00	0.03	704.00	682.88	t	3	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3802	14	53	2024-06-13	1	22.50	0.09	22.50	20.48	t	3	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3803	44	16	2024-06-13	10	26.00	0.10	260.00	234.00	t	3	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3804	68	51	2024-06-13	6	31.50	0.08	189.00	173.88	t	3	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3805	121	26	2024-06-13	6	22.00	0.03	132.00	128.04	t	3	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3806	143	39	2024-06-13	6	35.00	0.04	210.00	201.60	t	3	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3807	81	5	2024-06-13	9	60.00	0.00	540.00	540.00	f	3	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3808	140	30	2024-06-13	4	18.00	0.00	72.00	72.00	f	3	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3809	27	22	2024-06-13	10	54.00	0.04	540.00	518.40	t	3	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3810	84	13	2024-06-13	2	23.00	0.05	46.00	43.70	t	3	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3811	79	5	2024-06-13	1	60.00	0.01	60.00	59.40	t	3	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3812	125	42	2024-06-13	6	53.00	0.03	318.00	308.46	t	3	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3813	3	11	2024-06-13	6	32.00	0.04	192.00	184.32	t	3	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3814	17	34	2024-06-13	7	9.50	0.04	66.50	63.84	t	3	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3815	82	42	2024-06-13	7	53.00	0.08	371.00	341.32	t	3	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3816	148	36	2024-06-13	9	26.50	0.03	238.50	231.35	t	3	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3817	99	14	2024-06-13	8	12.00	0.01	96.00	95.04	t	3	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3818	4	38	2024-06-13	1	39.00	0.06	39.00	36.66	t	3	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3819	116	19	2024-06-13	6	38.00	0.02	228.00	223.44	t	3	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3820	22	27	2024-06-13	4	85.00	0.09	340.00	309.40	t	3	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3821	51	48	2024-06-14	9	44.50	0.05	400.50	380.47	t	4	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3822	22	31	2024-06-14	4	37.00	0.09	148.00	134.68	t	4	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3823	117	26	2024-06-14	3	22.00	0.02	66.00	64.68	t	4	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3824	11	43	2024-06-14	10	28.00	0.08	280.00	257.60	t	4	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3825	148	48	2024-06-14	1	44.50	0.08	44.50	40.94	t	4	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3826	140	22	2024-06-14	2	54.00	0.06	108.00	101.52	t	4	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3827	120	49	2024-06-14	3	39.50	0.04	118.50	113.76	t	4	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3828	29	39	2024-06-14	7	35.00	0.05	245.00	232.75	t	4	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3829	129	33	2024-06-14	5	21.00	0.09	105.00	95.55	t	4	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3830	102	20	2024-06-14	8	17.00	0.03	136.00	131.92	t	4	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3831	80	9	2024-06-14	10	36.00	0.09	360.00	327.60	t	4	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3832	2	41	2024-06-14	8	33.50	0.03	268.00	259.96	t	4	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3833	71	34	2024-06-14	1	9.50	0.02	9.50	9.31	t	4	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3834	114	14	2024-06-14	5	12.00	0.03	60.00	58.20	t	4	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3835	95	22	2024-06-15	6	54.00	0.00	324.00	324.00	f	5	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3836	41	42	2024-06-15	7	53.00	0.10	371.00	333.90	t	5	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3837	104	1	2024-06-15	5	30.00	0.04	150.00	144.00	t	5	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3838	129	14	2024-06-15	2	12.00	0.05	24.00	22.80	t	5	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3839	80	5	2024-06-15	9	60.00	0.03	540.00	523.80	t	5	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3840	121	2	2024-06-15	9	50.00	0.02	450.00	441.00	t	5	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3841	25	34	2024-06-15	6	9.50	0.02	57.00	55.86	t	5	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3842	113	33	2024-06-15	10	21.00	0.09	210.00	191.10	t	5	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3843	24	17	2024-06-15	6	80.00	0.09	480.00	436.80	t	5	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3844	49	1	2024-06-15	6	30.00	0.06	180.00	169.20	t	5	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3845	127	21	2024-06-15	10	34.00	0.06	340.00	319.60	t	5	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3846	134	4	2024-06-15	4	10.00	0.10	40.00	36.00	t	5	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3847	140	24	2024-06-15	5	11.00	0.04	55.00	52.80	t	5	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3848	93	28	2024-06-15	4	46.00	0.08	184.00	169.28	t	5	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3849	59	6	2024-06-15	9	25.00	0.05	225.00	213.75	t	5	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3850	150	34	2024-06-15	2	9.50	0.04	19.00	18.24	t	5	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3851	94	46	2024-06-15	5	25.50	0.00	127.50	127.50	f	5	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3852	110	12	2024-06-15	9	44.00	0.04	396.00	380.16	t	5	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3853	147	48	2024-06-15	7	44.50	0.06	311.50	292.81	t	5	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3854	45	20	2024-06-16	7	17.00	0.06	119.00	111.86	t	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3855	140	25	2024-06-16	10	65.00	0.03	650.00	630.50	t	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3856	129	52	2024-06-16	7	47.50	0.02	332.50	325.85	t	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3857	81	35	2024-06-16	7	63.00	0.06	441.00	414.54	t	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3858	97	26	2024-06-16	7	22.00	0.03	154.00	149.38	t	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3859	18	43	2024-06-16	2	28.00	0.06	56.00	52.64	t	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3860	64	43	2024-06-16	2	28.00	0.06	56.00	52.64	t	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3861	8	51	2024-06-16	10	31.50	0.06	315.00	296.10	t	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3862	28	10	2024-06-16	9	15.00	0.08	135.00	124.20	t	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3863	147	37	2024-06-16	6	88.00	0.08	528.00	485.76	t	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3864	7	20	2024-06-16	4	17.00	0.03	68.00	65.96	t	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3865	25	34	2024-06-16	4	9.50	0.05	38.00	36.10	t	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3866	56	17	2024-06-16	2	80.00	0.00	160.00	160.00	f	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3867	137	29	2024-06-16	8	40.00	0.07	320.00	297.60	t	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3868	119	28	2024-06-16	3	46.00	0.04	138.00	132.48	t	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3869	137	48	2024-06-16	9	44.50	0.07	400.50	372.47	t	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3870	73	44	2024-06-16	5	10.50	0.07	52.50	48.82	t	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3871	37	26	2024-06-16	3	22.00	0.05	66.00	62.70	t	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3872	109	14	2024-06-17	1	12.00	0.06	12.00	11.28	t	0	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3873	120	19	2024-06-17	1	38.00	0.05	38.00	36.10	t	0	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3874	143	4	2024-06-17	6	10.00	0.09	60.00	54.60	t	0	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3875	122	23	2024-06-17	2	24.00	0.05	48.00	45.60	t	0	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3876	100	4	2024-06-17	4	10.00	0.01	40.00	39.60	t	0	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3877	82	23	2024-06-17	9	24.00	0.03	216.00	209.52	t	0	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3878	58	49	2024-06-17	4	39.50	0.00	158.00	158.00	f	0	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3879	18	10	2024-06-17	1	15.00	0.01	15.00	14.85	t	0	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3880	48	15	2024-06-17	6	70.00	0.01	420.00	415.80	t	0	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3881	104	11	2024-06-17	3	32.00	0.00	96.00	96.00	f	0	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3882	17	31	2024-06-17	4	37.00	0.02	148.00	145.04	t	0	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3883	90	43	2024-06-17	2	28.00	0.09	56.00	50.96	t	0	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3884	140	46	2024-06-17	8	25.50	0.04	204.00	195.84	t	0	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3885	141	47	2024-06-17	7	82.50	0.04	577.50	554.40	t	0	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3886	46	16	2024-06-18	6	26.00	0.01	156.00	154.44	t	1	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3887	8	38	2024-06-18	5	39.00	0.03	195.00	189.15	t	1	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3888	40	34	2024-06-18	6	9.50	0.08	57.00	52.44	t	1	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3889	2	46	2024-06-18	1	25.50	0.02	25.50	24.99	t	1	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3890	70	49	2024-06-18	6	39.50	0.03	237.00	229.89	t	1	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3891	123	10	2024-06-18	8	15.00	0.05	120.00	114.00	t	1	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3892	94	36	2024-06-18	3	26.50	0.06	79.50	74.73	t	1	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3893	80	37	2024-06-18	9	88.00	0.10	792.00	712.80	t	1	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3894	124	53	2024-06-18	3	22.50	0.06	67.50	63.45	t	1	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3895	122	21	2024-06-18	6	34.00	0.06	204.00	191.76	t	1	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3896	74	47	2024-06-18	8	82.50	0.06	660.00	620.40	t	1	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3897	4	44	2024-06-18	2	10.50	0.00	21.00	21.00	f	1	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3898	107	9	2024-06-18	7	36.00	0.02	252.00	246.96	t	1	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3899	85	45	2024-06-18	5	59.50	0.02	297.50	291.55	t	1	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3900	34	36	2024-06-18	9	26.50	0.08	238.50	219.42	t	1	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3901	66	42	2024-06-18	1	53.00	0.02	53.00	51.94	t	1	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3902	72	20	2024-06-18	1	17.00	0.01	17.00	16.83	t	1	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3903	90	23	2024-06-19	7	24.00	0.03	168.00	162.96	t	2	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3904	81	15	2024-06-19	3	70.00	0.10	210.00	189.00	t	2	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3905	114	6	2024-06-19	10	25.00	0.06	250.00	235.00	t	2	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3906	132	20	2024-06-19	9	17.00	0.00	153.00	153.00	f	2	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3907	15	19	2024-06-19	2	38.00	0.09	76.00	69.16	t	2	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3908	85	44	2024-06-19	6	10.50	0.08	63.00	57.96	t	2	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3909	128	10	2024-06-19	9	15.00	0.04	135.00	129.60	t	2	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3910	46	20	2024-06-19	6	17.00	0.08	102.00	93.84	t	2	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3911	9	52	2024-06-19	6	47.50	0.09	285.00	259.35	t	2	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3912	139	44	2024-06-19	1	10.50	0.09	10.50	9.56	t	2	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3913	13	14	2024-06-19	10	12.00	0.06	120.00	112.80	t	2	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3914	111	7	2024-06-19	5	90.00	0.05	450.00	427.50	t	2	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3915	46	21	2024-06-19	9	34.00	0.09	306.00	278.46	t	2	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3916	138	30	2024-06-20	10	18.00	0.06	180.00	169.20	t	3	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3917	88	6	2024-06-20	9	25.00	0.02	225.00	220.50	t	3	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3918	91	34	2024-06-20	1	9.50	0.04	9.50	9.12	t	3	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3919	38	1	2024-06-20	3	30.00	0.02	90.00	88.20	t	3	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3920	65	38	2024-06-20	2	39.00	0.05	78.00	74.10	t	3	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3921	15	41	2024-06-20	3	33.50	0.00	100.50	100.50	f	3	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3922	41	38	2024-06-20	3	39.00	0.06	117.00	109.98	t	3	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3923	80	8	2024-06-20	6	40.00	0.07	240.00	223.20	t	3	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3924	97	20	2024-06-20	2	17.00	0.02	34.00	33.32	t	3	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3925	145	19	2024-06-20	5	38.00	0.04	190.00	182.40	t	3	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3926	77	40	2024-06-20	5	13.00	0.06	65.00	61.10	t	3	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3927	52	50	2024-06-20	4	17.50	0.08	70.00	64.40	t	3	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3928	39	50	2024-06-20	7	17.50	0.08	122.50	112.70	t	3	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3929	27	20	2024-06-20	2	17.00	0.05	34.00	32.30	t	3	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3930	34	49	2024-06-20	10	39.50	0.01	395.00	391.05	t	3	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3931	28	40	2024-06-20	6	13.00	0.04	78.00	74.88	t	3	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3932	77	11	2024-06-20	5	32.00	0.05	160.00	152.00	t	3	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3933	122	40	2024-06-20	7	13.00	0.02	91.00	89.18	t	3	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3934	130	29	2024-06-20	1	40.00	0.09	40.00	36.40	t	3	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3935	98	41	2024-06-20	7	33.50	0.03	234.50	227.47	t	3	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3936	59	34	2024-06-21	8	9.50	0.06	76.00	71.44	t	4	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3937	10	27	2024-06-21	2	85.00	0.03	170.00	164.90	t	4	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3938	102	35	2024-06-21	8	63.00	0.05	504.00	478.80	t	4	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3939	112	50	2024-06-21	8	17.50	0.06	140.00	131.60	t	4	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3940	26	33	2024-06-21	2	21.00	0.06	42.00	39.48	t	4	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3941	10	44	2024-06-21	10	10.50	0.02	105.00	102.90	t	4	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3942	69	26	2024-06-21	9	22.00	0.04	198.00	190.08	t	4	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3943	17	8	2024-06-21	4	40.00	0.06	160.00	150.40	t	4	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3944	60	20	2024-06-21	10	17.00	0.07	170.00	158.10	t	4	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3945	136	47	2024-06-21	2	82.50	0.02	165.00	161.70	t	4	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3946	149	43	2024-06-21	6	28.00	0.09	168.00	152.88	t	4	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3947	63	52	2024-06-21	6	47.50	0.03	285.00	276.45	t	4	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3948	137	44	2024-06-21	9	10.50	0.10	94.50	85.05	t	4	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3949	10	52	2024-06-22	8	47.50	0.09	380.00	345.80	t	5	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3950	15	3	2024-06-22	4	20.00	0.09	80.00	72.80	t	5	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3951	98	20	2024-06-22	2	17.00	0.01	34.00	33.66	t	5	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3952	126	31	2024-06-22	9	37.00	0.01	333.00	329.67	t	5	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3953	17	45	2024-06-22	10	59.50	0.09	595.00	541.45	t	5	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3954	75	25	2024-06-22	5	65.00	0.06	325.00	305.50	t	5	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3955	41	38	2024-06-22	3	39.00	0.09	117.00	106.47	t	5	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3956	92	11	2024-06-22	8	32.00	0.03	256.00	248.32	t	5	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3957	44	23	2024-06-22	5	24.00	0.06	120.00	112.80	t	5	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3958	83	24	2024-06-23	5	11.00	0.02	55.00	53.90	t	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3959	146	13	2024-06-23	10	23.00	0.04	230.00	220.80	t	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3960	6	7	2024-06-23	9	90.00	0.03	810.00	785.70	t	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3961	122	3	2024-06-23	8	20.00	0.06	160.00	150.40	t	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3962	57	35	2024-06-23	4	63.00	0.03	252.00	244.44	t	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3963	142	10	2024-06-23	6	15.00	0.08	90.00	82.80	t	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3964	102	53	2024-06-23	6	22.50	0.06	135.00	126.90	t	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3965	74	47	2024-06-23	2	82.50	0.01	165.00	163.35	t	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3966	112	20	2024-06-23	2	17.00	0.03	34.00	32.98	t	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3967	77	39	2024-06-24	10	35.00	0.08	350.00	322.00	t	0	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3968	43	28	2024-06-24	1	46.00	0.08	46.00	42.32	t	0	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3969	74	7	2024-06-24	1	90.00	0.08	90.00	82.80	t	0	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3970	38	38	2024-06-24	5	39.00	0.03	195.00	189.15	t	0	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3971	88	21	2024-06-24	5	34.00	0.01	170.00	168.30	t	0	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3972	106	15	2024-06-24	10	70.00	0.06	700.00	658.00	t	0	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3973	121	4	2024-06-24	6	10.00	0.09	60.00	54.60	t	0	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3974	139	25	2024-06-24	8	65.00	0.04	520.00	499.20	t	0	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3975	66	29	2024-06-24	10	40.00	0.04	400.00	384.00	t	0	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3976	73	28	2024-06-24	5	46.00	0.00	230.00	230.00	f	0	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3977	81	13	2024-06-24	6	23.00	0.08	138.00	126.96	t	0	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3978	96	1	2024-06-24	2	30.00	0.08	60.00	55.20	t	0	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3979	32	2	2024-06-24	9	50.00	0.05	450.00	427.50	t	0	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3980	45	47	2024-06-24	8	82.50	0.06	660.00	620.40	t	0	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3981	81	30	2024-06-25	1	18.00	0.01	18.00	17.82	t	1	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3982	148	25	2024-06-25	4	65.00	0.01	260.00	257.40	t	1	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3983	87	12	2024-06-25	7	44.00	0.08	308.00	283.36	t	1	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3984	37	43	2024-06-25	5	28.00	0.09	140.00	127.40	t	1	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3985	130	6	2024-06-25	10	25.00	0.09	250.00	227.50	t	1	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3986	55	53	2024-06-25	10	22.50	0.04	225.00	216.00	t	1	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3987	142	34	2024-06-25	4	9.50	0.05	38.00	36.10	t	1	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3988	77	8	2024-06-25	5	40.00	0.05	200.00	190.00	t	1	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3989	108	34	2024-06-26	4	9.50	0.04	38.00	36.48	t	2	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3990	137	42	2024-06-26	3	53.00	0.09	159.00	144.69	t	2	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3991	105	14	2024-06-26	9	12.00	0.04	108.00	103.68	t	2	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3992	24	6	2024-06-26	1	25.00	0.04	25.00	24.00	t	2	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3993	68	44	2024-06-26	7	10.50	0.09	73.50	66.89	t	2	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3994	63	16	2024-06-26	5	26.00	0.08	130.00	119.60	t	2	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3995	93	37	2024-06-26	4	88.00	0.07	352.00	327.36	t	2	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3996	148	32	2024-06-26	5	48.00	0.03	240.00	232.80	t	2	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3997	100	30	2024-06-26	3	18.00	0.00	54.00	54.00	f	2	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3998	59	48	2024-06-26	2	44.50	0.00	89.00	89.00	f	2	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
3999	5	32	2024-06-26	10	48.00	0.06	480.00	451.20	t	2	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4000	22	42	2024-06-26	2	53.00	0.00	106.00	106.00	f	2	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4001	75	38	2024-06-26	6	39.00	0.08	234.00	215.28	t	2	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4002	80	48	2024-06-26	5	44.50	0.04	222.50	213.60	t	2	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4003	25	12	2024-06-26	3	44.00	0.04	132.00	126.72	t	2	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4004	41	42	2024-06-26	5	53.00	0.03	265.00	257.05	t	2	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4005	132	53	2024-06-27	9	22.50	0.06	202.50	190.35	t	3	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4006	43	39	2024-06-27	4	35.00	0.01	140.00	138.60	t	3	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4007	78	31	2024-06-27	7	37.00	0.08	259.00	238.28	t	3	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4008	19	50	2024-06-27	10	17.50	0.06	175.00	164.50	t	3	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4009	121	53	2024-06-27	8	22.50	0.09	180.00	163.80	t	3	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4010	131	35	2024-06-27	3	63.00	0.04	189.00	181.44	t	3	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4011	121	52	2024-06-27	6	47.50	0.07	285.00	265.05	t	3	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4012	63	2	2024-06-27	5	50.00	0.08	250.00	230.00	t	3	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4013	66	53	2024-06-27	3	22.50	0.01	67.50	66.83	t	3	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4014	17	9	2024-06-27	2	36.00	0.10	72.00	64.80	t	3	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4015	37	28	2024-06-27	4	46.00	0.03	184.00	178.48	t	3	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4016	70	2	2024-06-27	8	50.00	0.04	400.00	384.00	t	3	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4017	135	8	2024-06-27	5	40.00	0.02	200.00	196.00	t	3	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4018	126	52	2024-06-27	5	47.50	0.02	237.50	232.75	t	3	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4019	121	48	2024-06-27	3	44.50	0.03	133.50	129.50	t	3	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4020	46	8	2024-06-27	2	40.00	0.04	80.00	76.80	t	3	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4021	41	30	2024-06-28	2	18.00	0.10	36.00	32.40	t	4	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4022	68	51	2024-06-28	2	31.50	0.05	63.00	59.85	t	4	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4023	87	22	2024-06-28	3	54.00	0.10	162.00	145.80	t	4	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4024	75	53	2024-06-28	3	22.50	0.04	67.50	64.80	t	4	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4025	147	6	2024-06-28	9	25.00	0.04	225.00	216.00	t	4	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4026	150	27	2024-06-28	7	85.00	0.07	595.00	553.35	t	4	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4027	129	17	2024-06-28	5	80.00	0.09	400.00	364.00	t	4	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4028	75	47	2024-06-28	4	82.50	0.03	330.00	320.10	t	4	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4029	19	48	2024-06-28	7	44.50	0.09	311.50	283.47	t	4	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4030	94	53	2024-06-28	9	22.50	0.08	202.50	186.30	t	4	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4031	16	9	2024-06-28	3	36.00	0.05	108.00	102.60	t	4	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4032	3	13	2024-06-28	8	23.00	0.05	184.00	174.80	t	4	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4033	26	51	2024-06-28	4	31.50	0.03	126.00	122.22	t	4	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4034	137	19	2024-06-28	8	38.00	0.08	304.00	279.68	t	4	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4035	24	30	2024-06-28	5	18.00	0.03	90.00	87.30	t	4	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4036	15	31	2024-06-28	5	37.00	0.04	185.00	177.60	t	4	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4037	23	46	2024-06-28	8	25.50	0.02	204.00	199.92	t	4	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4038	145	3	2024-06-28	9	20.00	0.04	180.00	172.80	t	4	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4039	117	3	2024-06-28	9	20.00	0.03	180.00	174.60	t	4	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4040	31	3	2024-06-28	7	20.00	0.03	140.00	135.80	t	4	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4041	139	40	2024-06-28	7	13.00	0.08	91.00	83.72	t	4	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4042	126	45	2024-06-28	1	59.50	0.04	59.50	57.12	t	4	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4043	102	46	2024-06-28	8	25.50	0.04	204.00	195.84	t	4	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4044	144	21	2024-06-29	10	34.00	0.06	340.00	319.60	t	5	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4045	144	5	2024-06-29	4	60.00	0.10	240.00	216.00	t	5	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4046	130	11	2024-06-29	2	32.00	0.04	64.00	61.44	t	5	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4047	136	44	2024-06-29	2	10.50	0.07	21.00	19.53	t	5	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4048	136	19	2024-06-29	5	38.00	0.08	190.00	174.80	t	5	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4049	33	40	2024-06-29	7	13.00	0.02	91.00	89.18	t	5	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4050	90	26	2024-06-29	7	22.00	0.02	154.00	150.92	t	5	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4051	89	36	2024-06-29	6	26.50	0.07	159.00	147.87	t	5	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4052	43	50	2024-06-29	10	17.50	0.08	175.00	161.00	t	5	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4053	137	37	2024-06-29	9	88.00	0.02	792.00	776.16	t	5	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4054	116	53	2024-06-29	4	22.50	0.08	90.00	82.80	t	5	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4055	58	29	2024-06-29	5	40.00	0.02	200.00	196.00	t	5	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4056	42	35	2024-06-29	9	63.00	0.06	567.00	532.98	t	5	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4057	23	7	2024-06-29	2	90.00	0.07	180.00	167.40	t	5	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4058	79	26	2024-06-29	7	22.00	0.05	154.00	146.30	t	5	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4059	142	35	2024-06-29	9	63.00	0.07	567.00	527.31	t	5	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4060	64	1	2024-06-29	10	30.00	0.01	300.00	297.00	t	5	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4061	42	34	2024-06-29	4	9.50	0.09	38.00	34.58	t	5	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4062	29	9	2024-06-29	10	36.00	0.09	360.00	327.60	t	5	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4063	150	44	2024-06-29	1	10.50	0.06	10.50	9.87	t	5	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4064	78	44	2024-06-29	9	10.50	0.08	94.50	86.94	t	5	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4065	80	18	2024-06-30	4	43.00	0.08	172.00	158.24	t	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4066	62	50	2024-06-30	10	17.50	0.02	175.00	171.50	t	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4067	48	30	2024-06-30	7	18.00	0.09	126.00	114.66	t	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4068	85	35	2024-06-30	4	63.00	0.02	252.00	246.96	t	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4069	73	21	2024-06-30	2	34.00	0.00	68.00	68.00	f	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4070	142	10	2024-06-30	4	15.00	0.05	60.00	57.00	t	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4071	117	5	2024-06-30	9	60.00	0.02	540.00	529.20	t	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4072	133	41	2024-06-30	1	33.50	0.09	33.50	30.49	t	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4073	11	5	2024-06-30	1	60.00	0.05	60.00	57.00	t	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4074	66	14	2024-06-30	1	12.00	0.03	12.00	11.64	t	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4075	7	47	2024-06-30	8	82.50	0.09	660.00	600.60	t	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4076	113	4	2024-06-30	1	10.00	0.03	10.00	9.70	t	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4077	62	5	2024-06-30	5	60.00	0.07	300.00	279.00	t	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4078	14	29	2024-06-30	1	40.00	0.07	40.00	37.20	t	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4079	21	14	2024-06-30	4	12.00	0.03	48.00	46.56	t	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4080	140	31	2024-06-30	5	37.00	0.06	185.00	173.90	t	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4081	46	25	2024-06-30	10	65.00	0.06	650.00	611.00	t	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4082	59	43	2024-06-30	10	28.00	0.02	280.00	274.40	t	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4083	90	13	2024-06-30	6	23.00	0.01	138.00	136.62	t	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4084	68	27	2024-06-30	10	85.00	0.07	850.00	790.50	t	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4085	25	17	2024-06-30	2	80.00	0.04	160.00	153.60	t	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4086	72	29	2024-06-30	2	40.00	0.03	80.00	77.60	t	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4087	105	6	2024-06-30	5	25.00	0.09	125.00	113.75	t	6	6	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4088	69	51	2024-07-01	8	31.50	0.05	252.00	239.40	t	0	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4089	12	7	2024-07-01	8	90.00	0.05	720.00	684.00	t	0	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4090	80	40	2024-07-01	10	13.00	0.03	130.00	126.10	t	0	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4091	88	51	2024-07-01	4	31.50	0.07	126.00	117.18	t	0	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4092	28	14	2024-07-01	1	12.00	0.03	12.00	11.64	t	0	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4093	7	5	2024-07-01	8	60.00	0.09	480.00	436.80	t	0	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4094	123	32	2024-07-01	6	48.00	0.01	288.00	285.12	t	0	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4095	21	34	2024-07-01	8	9.50	0.02	76.00	74.48	t	0	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4096	107	2	2024-07-01	7	50.00	0.00	350.00	350.00	f	0	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4097	134	31	2024-07-01	9	37.00	0.08	333.00	306.36	t	0	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4098	141	20	2024-07-01	9	17.00	0.10	153.00	137.70	t	0	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4099	42	24	2024-07-01	2	11.00	0.02	22.00	21.56	t	0	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4100	37	3	2024-07-01	2	20.00	0.05	40.00	38.00	t	0	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4101	126	17	2024-07-01	7	80.00	0.07	560.00	520.80	t	0	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4102	148	15	2024-07-01	3	70.00	0.09	210.00	191.10	t	0	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4103	61	46	2024-07-01	8	25.50	0.02	204.00	199.92	t	0	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4104	123	49	2024-07-01	8	39.50	0.01	316.00	312.84	t	0	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4105	67	52	2024-07-02	2	47.50	0.10	95.00	85.50	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4106	75	26	2024-07-02	2	22.00	0.01	44.00	43.56	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4107	29	13	2024-07-02	5	23.00	0.06	115.00	108.10	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4108	61	30	2024-07-02	6	18.00	0.00	108.00	108.00	f	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4109	42	51	2024-07-02	5	31.50	0.02	157.50	154.35	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4110	7	21	2024-07-02	2	34.00	0.02	68.00	66.64	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4111	139	39	2024-07-02	6	35.00	0.04	210.00	201.60	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4112	35	18	2024-07-02	10	43.00	0.08	430.00	395.60	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4113	91	23	2024-07-02	2	24.00	0.10	48.00	43.20	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4114	25	19	2024-07-02	10	38.00	0.01	380.00	376.20	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4115	50	44	2024-07-02	9	10.50	0.05	94.50	89.77	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4116	129	35	2024-07-02	3	63.00	0.03	189.00	183.33	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4117	116	27	2024-07-02	9	85.00	0.07	765.00	711.45	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4118	106	27	2024-07-02	1	85.00	0.05	85.00	80.75	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4119	23	2	2024-07-02	6	50.00	0.05	300.00	285.00	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4120	128	2	2024-07-02	7	50.00	0.02	350.00	343.00	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4121	92	38	2024-07-02	3	39.00	0.05	117.00	111.15	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4122	16	39	2024-07-02	6	35.00	0.08	210.00	193.20	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4123	13	23	2024-07-02	2	24.00	0.05	48.00	45.60	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4124	59	34	2024-07-02	5	9.50	0.05	47.50	45.13	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4125	86	37	2024-07-02	10	88.00	0.02	880.00	862.40	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4126	50	2	2024-07-03	5	50.00	0.05	250.00	237.50	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4127	2	16	2024-07-03	2	26.00	0.01	52.00	51.48	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4128	87	26	2024-07-03	1	22.00	0.02	22.00	21.56	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4129	99	8	2024-07-03	9	40.00	0.00	360.00	360.00	f	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4130	148	4	2024-07-03	4	10.00	0.07	40.00	37.20	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4131	100	20	2024-07-03	9	17.00	0.00	153.00	153.00	f	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4132	108	7	2024-07-03	7	90.00	0.01	630.00	623.70	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4133	1	7	2024-07-03	1	90.00	0.09	90.00	81.90	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4134	45	37	2024-07-03	4	88.00	0.01	352.00	348.48	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4135	37	42	2024-07-03	6	53.00	0.07	318.00	295.74	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4136	38	53	2024-07-03	2	22.50	0.01	45.00	44.55	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4137	2	37	2024-07-03	6	88.00	0.05	528.00	501.60	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4138	118	28	2024-07-03	7	46.00	0.08	322.00	296.24	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4139	118	4	2024-07-03	6	10.00	0.09	60.00	54.60	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4140	113	25	2024-07-03	3	65.00	0.02	195.00	191.10	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4141	49	39	2024-07-03	8	35.00	0.02	280.00	274.40	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4142	130	29	2024-07-03	8	40.00	0.08	320.00	294.40	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4143	56	36	2024-07-03	3	26.50	0.01	79.50	78.71	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4144	96	34	2024-07-03	2	9.50	0.07	19.00	17.67	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4145	6	46	2024-07-03	6	25.50	0.01	153.00	151.47	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4146	142	44	2024-07-03	5	10.50	0.00	52.50	52.50	f	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4147	55	1	2024-07-03	9	30.00	0.01	270.00	267.30	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4148	95	38	2024-07-03	9	39.00	0.08	351.00	322.92	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4149	59	11	2024-07-04	9	32.00	0.02	288.00	282.24	t	3	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4150	105	31	2024-07-04	1	37.00	0.09	37.00	33.67	t	3	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4151	23	7	2024-07-04	4	90.00	0.06	360.00	338.40	t	3	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4152	129	13	2024-07-04	5	23.00	0.01	115.00	113.85	t	3	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4153	67	37	2024-07-04	2	88.00	0.02	176.00	172.48	t	3	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4154	144	4	2024-07-04	10	10.00	0.04	100.00	96.00	t	3	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4155	38	40	2024-07-04	6	13.00	0.05	78.00	74.10	t	3	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4156	140	34	2024-07-04	8	9.50	0.04	76.00	72.96	t	3	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4157	84	22	2024-07-04	8	54.00	0.09	432.00	393.12	t	3	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4158	83	49	2024-07-04	9	39.50	0.04	355.50	341.28	t	3	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4159	30	19	2024-07-04	2	38.00	0.05	76.00	72.20	t	3	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4160	139	6	2024-07-04	3	25.00	0.01	75.00	74.25	t	3	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4161	72	31	2024-07-04	1	37.00	0.08	37.00	34.04	t	3	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4162	47	12	2024-07-04	10	44.00	0.00	440.00	440.00	f	3	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4163	127	1	2024-07-04	10	30.00	0.04	300.00	288.00	t	3	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4164	55	26	2024-07-04	5	22.00	0.08	110.00	101.20	t	3	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4165	125	25	2024-07-04	4	65.00	0.06	260.00	244.40	t	3	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4166	50	14	2024-07-05	9	12.00	0.04	108.00	103.68	t	4	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4167	56	3	2024-07-05	7	20.00	0.06	140.00	131.60	t	4	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4168	22	16	2024-07-05	6	26.00	0.08	156.00	143.52	t	4	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4169	91	11	2024-07-05	7	32.00	0.07	224.00	208.32	t	4	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4170	131	4	2024-07-05	10	10.00	0.01	100.00	99.00	t	4	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4171	76	46	2024-07-05	9	25.50	0.09	229.50	208.85	t	4	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4172	41	26	2024-07-05	5	22.00	0.06	110.00	103.40	t	4	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4173	38	43	2024-07-05	5	28.00	0.08	140.00	128.80	t	4	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4174	2	38	2024-07-05	8	39.00	0.04	312.00	299.52	t	4	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4175	29	33	2024-07-05	8	21.00	0.04	168.00	161.28	t	4	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4176	74	14	2024-07-05	7	12.00	0.03	84.00	81.48	t	4	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4177	69	2	2024-07-05	10	50.00	0.09	500.00	455.00	t	4	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4178	3	23	2024-07-05	6	24.00	0.09	144.00	131.04	t	4	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4179	31	22	2024-07-06	2	54.00	0.03	108.00	104.76	t	5	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4180	28	16	2024-07-06	7	26.00	0.05	182.00	172.90	t	5	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4181	130	42	2024-07-06	5	53.00	0.05	265.00	251.75	t	5	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4182	126	20	2024-07-06	10	17.00	0.04	170.00	163.20	t	5	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4183	16	50	2024-07-06	5	17.50	0.06	87.50	82.25	t	5	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4184	102	42	2024-07-06	9	53.00	0.06	477.00	448.38	t	5	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4185	31	15	2024-07-06	2	70.00	0.09	140.00	127.40	t	5	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4186	114	5	2024-07-06	8	60.00	0.01	480.00	475.20	t	5	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4187	73	34	2024-07-06	4	9.50	0.08	38.00	34.96	t	5	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4188	48	12	2024-07-06	5	44.00	0.02	220.00	215.60	t	5	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4189	130	31	2024-07-06	1	37.00	0.01	37.00	36.63	t	5	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4190	52	36	2024-07-06	8	26.50	0.03	212.00	205.64	t	5	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4191	16	40	2024-07-06	8	13.00	0.08	104.00	95.68	t	5	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4192	81	31	2024-07-06	3	37.00	0.07	111.00	103.23	t	5	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4193	141	36	2024-07-06	4	26.50	0.03	106.00	102.82	t	5	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4194	29	4	2024-07-06	2	10.00	0.03	20.00	19.40	t	5	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4195	66	45	2024-07-06	5	59.50	0.08	297.50	273.70	t	5	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4196	41	42	2024-07-06	1	53.00	0.06	53.00	49.82	t	5	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4197	67	7	2024-07-06	2	90.00	0.06	180.00	169.20	t	5	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4198	28	47	2024-07-06	4	82.50	0.03	330.00	320.10	t	5	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4199	150	41	2024-07-07	4	33.50	0.00	134.00	134.00	f	6	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4200	15	26	2024-07-07	1	22.00	0.06	22.00	20.68	t	6	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4201	105	46	2024-07-07	7	25.50	0.01	178.50	176.72	t	6	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4202	93	12	2024-07-07	7	44.00	0.06	308.00	289.52	t	6	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4203	43	6	2024-07-07	1	25.00	0.02	25.00	24.50	t	6	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4204	57	11	2024-07-07	5	32.00	0.04	160.00	153.60	t	6	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4205	69	8	2024-07-07	5	40.00	0.09	200.00	182.00	t	6	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4206	129	7	2024-07-07	1	90.00	0.08	90.00	82.80	t	6	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4207	6	14	2024-07-07	1	12.00	0.07	12.00	11.16	t	6	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4208	137	14	2024-07-07	3	12.00	0.03	36.00	34.92	t	6	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4209	121	11	2024-07-07	6	32.00	0.09	192.00	174.72	t	6	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4210	25	36	2024-07-07	7	26.50	0.00	185.50	185.50	f	6	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4211	18	50	2024-07-07	7	17.50	0.09	122.50	111.48	t	6	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4212	100	43	2024-07-07	10	28.00	0.06	280.00	263.20	t	6	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4213	98	26	2024-07-07	4	22.00	0.08	88.00	80.96	t	6	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4214	140	47	2024-07-07	8	82.50	0.01	660.00	653.40	t	6	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4215	30	1	2024-07-07	8	30.00	0.02	240.00	235.20	t	6	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4216	120	47	2024-07-07	3	82.50	0.10	247.50	222.75	t	6	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4217	37	9	2024-07-07	10	36.00	0.08	360.00	331.20	t	6	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4218	90	39	2024-07-08	9	35.00	0.03	315.00	305.55	t	0	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4219	54	13	2024-07-08	9	23.00	0.02	207.00	202.86	t	0	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4220	150	6	2024-07-08	9	25.00	0.03	225.00	218.25	t	0	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4221	73	8	2024-07-08	7	40.00	0.08	280.00	257.60	t	0	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4222	16	13	2024-07-08	8	23.00	0.01	184.00	182.16	t	0	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4223	65	19	2024-07-08	2	38.00	0.05	76.00	72.20	t	0	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4224	134	15	2024-07-08	8	70.00	0.04	560.00	537.60	t	0	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4225	81	40	2024-07-08	2	13.00	0.03	26.00	25.22	t	0	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4226	29	41	2024-07-08	5	33.50	0.03	167.50	162.48	t	0	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4227	126	3	2024-07-08	7	20.00	0.01	140.00	138.60	t	0	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4228	60	13	2024-07-08	5	23.00	0.05	115.00	109.25	t	0	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4229	79	26	2024-07-08	7	22.00	0.09	154.00	140.14	t	0	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4230	46	19	2024-07-08	6	38.00	0.04	228.00	218.88	t	0	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4231	108	6	2024-07-08	6	25.00	0.08	150.00	138.00	t	0	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4232	119	53	2024-07-08	3	22.50	0.04	67.50	64.80	t	0	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4233	135	6	2024-07-08	4	25.00	0.10	100.00	90.00	t	0	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4234	46	31	2024-07-08	9	37.00	0.04	333.00	319.68	t	0	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4235	89	39	2024-07-08	7	35.00	0.07	245.00	227.85	t	0	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4236	109	36	2024-07-08	6	26.50	0.00	159.00	159.00	f	0	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4237	134	17	2024-07-08	3	80.00	0.06	240.00	225.60	t	0	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4238	85	29	2024-07-08	4	40.00	0.06	160.00	150.40	t	0	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4239	67	10	2024-07-08	10	15.00	0.10	150.00	135.00	t	0	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4240	59	17	2024-07-09	8	80.00	0.04	640.00	614.40	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4241	107	35	2024-07-09	10	63.00	0.06	630.00	592.20	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4242	85	45	2024-07-09	5	59.50	0.02	297.50	291.55	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4243	32	38	2024-07-09	6	39.00	0.04	234.00	224.64	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4244	66	32	2024-07-09	7	48.00	0.05	336.00	319.20	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4245	92	41	2024-07-09	5	33.50	0.08	167.50	154.10	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4246	78	27	2024-07-09	7	85.00	0.07	595.00	553.35	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4247	118	30	2024-07-09	8	18.00	0.02	144.00	141.12	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4248	140	51	2024-07-09	10	31.50	0.07	315.00	292.95	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4249	88	23	2024-07-09	3	24.00	0.03	72.00	69.84	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4250	8	22	2024-07-09	10	54.00	0.05	540.00	513.00	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4251	68	21	2024-07-09	2	34.00	0.06	68.00	63.92	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4252	73	32	2024-07-10	1	48.00	0.10	48.00	43.20	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4253	47	43	2024-07-10	6	28.00	0.06	168.00	157.92	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4254	150	41	2024-07-10	1	33.50	0.07	33.50	31.15	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4255	108	19	2024-07-10	2	38.00	0.08	76.00	69.92	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4256	100	42	2024-07-10	9	53.00	0.02	477.00	467.46	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4257	95	22	2024-07-10	1	54.00	0.01	54.00	53.46	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4258	38	9	2024-07-10	7	36.00	0.07	252.00	234.36	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4259	132	15	2024-07-10	7	70.00	0.08	490.00	450.80	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4260	134	27	2024-07-10	3	85.00	0.08	255.00	234.60	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4261	71	23	2024-07-10	3	24.00	0.08	72.00	66.24	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4262	138	30	2024-07-10	10	18.00	0.07	180.00	167.40	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4263	104	47	2024-07-10	6	82.50	0.06	495.00	465.30	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4264	21	36	2024-07-10	7	26.50	0.07	185.50	172.52	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4265	103	27	2024-07-10	4	85.00	0.01	340.00	336.60	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4266	92	20	2024-07-10	7	17.00	0.05	119.00	113.05	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4267	111	20	2024-07-10	5	17.00	0.04	85.00	81.60	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4268	69	31	2024-07-10	6	37.00	0.04	222.00	213.12	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4269	150	38	2024-07-11	9	39.00	0.08	351.00	322.92	t	3	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4270	56	3	2024-07-11	7	20.00	0.05	140.00	133.00	t	3	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4271	49	29	2024-07-11	10	40.00	0.03	400.00	388.00	t	3	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4272	99	7	2024-07-11	6	90.00	0.03	540.00	523.80	t	3	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4273	130	52	2024-07-11	4	47.50	0.01	190.00	188.10	t	3	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4274	95	12	2024-07-11	7	44.00	0.08	308.00	283.36	t	3	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4275	24	2	2024-07-11	1	50.00	0.04	50.00	48.00	t	3	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4276	31	42	2024-07-11	7	53.00	0.07	371.00	345.03	t	3	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4277	73	53	2024-07-11	4	22.50	0.09	90.00	81.90	t	3	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4278	99	41	2024-07-11	8	33.50	0.05	268.00	254.60	t	3	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4279	2	6	2024-07-11	1	25.00	0.10	25.00	22.50	t	3	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4280	82	30	2024-07-11	1	18.00	0.01	18.00	17.82	t	3	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4281	37	37	2024-07-11	9	88.00	0.10	792.00	712.80	t	3	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4282	60	38	2024-07-11	1	39.00	0.05	39.00	37.05	t	3	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4283	107	1	2024-07-11	4	30.00	0.04	120.00	115.20	t	3	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4284	76	1	2024-07-11	7	30.00	0.02	210.00	205.80	t	3	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4285	3	23	2024-07-11	10	24.00	0.04	240.00	230.40	t	3	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4286	136	5	2024-07-11	2	60.00	0.07	120.00	111.60	t	3	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4287	103	43	2024-07-11	6	28.00	0.01	168.00	166.32	t	3	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4288	106	44	2024-07-11	10	10.50	0.03	105.00	101.85	t	3	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4289	95	18	2024-07-11	6	43.00	0.01	258.00	255.42	t	3	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4290	52	52	2024-07-12	9	47.50	0.02	427.50	418.95	t	4	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4291	59	29	2024-07-12	4	40.00	0.10	160.00	144.00	t	4	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4292	122	44	2024-07-12	4	10.50	0.01	42.00	41.58	t	4	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4293	44	20	2024-07-12	10	17.00	0.02	170.00	166.60	t	4	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4294	104	44	2024-07-12	8	10.50	0.01	84.00	83.16	t	4	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4295	136	45	2024-07-12	1	59.50	0.07	59.50	55.33	t	4	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4296	87	9	2024-07-12	4	36.00	0.00	144.00	144.00	f	4	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4297	50	32	2024-07-12	4	48.00	0.03	192.00	186.24	t	4	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4298	1	51	2024-07-12	4	31.50	0.03	126.00	122.22	t	4	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4299	42	22	2024-07-12	7	54.00	0.05	378.00	359.10	t	4	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4300	26	52	2024-07-12	8	47.50	0.01	380.00	376.20	t	4	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4301	128	14	2024-07-12	1	12.00	0.06	12.00	11.28	t	4	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4302	98	53	2024-07-12	8	22.50	0.04	180.00	172.80	t	4	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4303	93	20	2024-07-12	10	17.00	0.00	170.00	170.00	f	4	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4304	139	35	2024-07-12	4	63.00	0.08	252.00	231.84	t	4	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4305	136	53	2024-07-12	2	22.50	0.08	45.00	41.40	t	4	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4306	30	20	2024-07-12	4	17.00	0.05	68.00	64.60	t	4	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4307	112	35	2024-07-12	2	63.00	0.05	126.00	119.70	t	4	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4308	77	9	2024-07-12	2	36.00	0.05	72.00	68.40	t	4	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4309	13	30	2024-07-13	1	18.00	0.01	18.00	17.82	t	5	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4310	28	52	2024-07-13	6	47.50	0.08	285.00	262.20	t	5	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4311	87	26	2024-07-13	10	22.00	0.05	220.00	209.00	t	5	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4312	87	49	2024-07-13	3	39.50	0.01	118.50	117.32	t	5	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4313	145	13	2024-07-13	5	23.00	0.09	115.00	104.65	t	5	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4314	146	14	2024-07-13	6	12.00	0.02	72.00	70.56	t	5	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4315	94	49	2024-07-13	3	39.50	0.01	118.50	117.32	t	5	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4316	139	47	2024-07-13	8	82.50	0.07	660.00	613.80	t	5	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4317	143	8	2024-07-13	3	40.00	0.05	120.00	114.00	t	5	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4318	94	15	2024-07-13	7	70.00	0.03	490.00	475.30	t	5	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4319	77	35	2024-07-13	1	63.00	0.00	63.00	63.00	f	5	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4320	78	2	2024-07-13	5	50.00	0.01	250.00	247.50	t	5	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4321	81	45	2024-07-14	9	59.50	0.00	535.50	535.50	f	6	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4322	28	42	2024-07-14	7	53.00	0.10	371.00	333.90	t	6	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4323	141	25	2024-07-14	9	65.00	0.07	585.00	544.05	t	6	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4324	80	33	2024-07-14	5	21.00	0.02	105.00	102.90	t	6	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4325	34	48	2024-07-14	10	44.50	0.03	445.00	431.65	t	6	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4326	115	14	2024-07-14	6	12.00	0.01	72.00	71.28	t	6	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4327	137	23	2024-07-14	10	24.00	0.02	240.00	235.20	t	6	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4328	16	29	2024-07-14	6	40.00	0.02	240.00	235.20	t	6	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4329	6	8	2024-07-14	6	40.00	0.02	240.00	235.20	t	6	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4330	43	28	2024-07-14	2	46.00	0.08	92.00	84.64	t	6	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4331	18	36	2024-07-14	10	26.50	0.10	265.00	238.50	t	6	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4332	120	20	2024-07-14	9	17.00	0.07	153.00	142.29	t	6	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4333	124	38	2024-07-14	5	39.00	0.02	195.00	191.10	t	6	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4334	132	15	2024-07-14	9	70.00	0.10	630.00	567.00	t	6	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4335	83	37	2024-07-14	5	88.00	0.06	440.00	413.60	t	6	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4336	53	1	2024-07-15	4	30.00	0.05	120.00	114.00	t	0	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4337	35	9	2024-07-15	8	36.00	0.02	288.00	282.24	t	0	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4338	149	52	2024-07-15	5	47.50	0.04	237.50	228.00	t	0	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4339	7	53	2024-07-15	9	22.50	0.01	202.50	200.48	t	0	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4340	139	24	2024-07-15	8	11.00	0.05	88.00	83.60	t	0	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4341	14	9	2024-07-15	5	36.00	0.08	180.00	165.60	t	0	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4342	133	40	2024-07-15	6	13.00	0.03	78.00	75.66	t	0	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4343	84	8	2024-07-15	6	40.00	0.00	240.00	240.00	f	0	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4344	3	26	2024-07-15	10	22.00	0.01	220.00	217.80	t	0	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4345	50	38	2024-07-15	7	39.00	0.04	273.00	262.08	t	0	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4346	15	32	2024-07-15	9	48.00	0.00	432.00	432.00	f	0	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4347	114	29	2024-07-15	3	40.00	0.07	120.00	111.60	t	0	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4348	136	20	2024-07-15	10	17.00	0.08	170.00	156.40	t	0	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4349	86	34	2024-07-16	9	9.50	0.02	85.50	83.79	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4350	130	31	2024-07-16	6	37.00	0.06	222.00	208.68	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4351	89	34	2024-07-16	8	9.50	0.02	76.00	74.48	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4352	8	2	2024-07-16	10	50.00	0.04	500.00	480.00	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4353	14	32	2024-07-16	4	48.00	0.08	192.00	176.64	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4354	146	21	2024-07-16	10	34.00	0.10	340.00	306.00	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4355	60	42	2024-07-16	10	53.00	0.07	530.00	492.90	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4356	99	4	2024-07-16	5	10.00	0.07	50.00	46.50	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4357	41	35	2024-07-16	9	63.00	0.03	567.00	549.99	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4358	38	45	2024-07-16	9	59.50	0.08	535.50	492.66	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4359	108	9	2024-07-16	6	36.00	0.06	216.00	203.04	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4360	22	30	2024-07-16	7	18.00	0.07	126.00	117.18	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4361	9	31	2024-07-16	4	37.00	0.08	148.00	136.16	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4362	6	17	2024-07-16	9	80.00	0.07	720.00	669.60	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4363	150	30	2024-07-16	7	18.00	0.05	126.00	119.70	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4364	101	8	2024-07-16	6	40.00	0.05	240.00	228.00	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4365	102	53	2024-07-16	1	22.50	0.07	22.50	20.92	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4366	36	42	2024-07-16	4	53.00	0.07	212.00	197.16	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4367	80	5	2024-07-17	5	60.00	0.08	300.00	276.00	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4368	76	11	2024-07-17	2	32.00	0.05	64.00	60.80	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4369	45	34	2024-07-17	3	9.50	0.03	28.50	27.65	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4370	104	2	2024-07-17	9	50.00	0.02	450.00	441.00	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4371	46	49	2024-07-17	2	39.50	0.07	79.00	73.47	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4372	23	8	2024-07-17	5	40.00	0.04	200.00	192.00	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4373	135	4	2024-07-17	1	10.00	0.04	10.00	9.60	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4374	99	43	2024-07-17	4	28.00	0.07	112.00	104.16	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4375	83	16	2024-07-17	7	26.00	0.04	182.00	174.72	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4376	92	46	2024-07-17	5	25.50	0.05	127.50	121.13	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4377	131	49	2024-07-17	1	39.50	0.03	39.50	38.32	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4378	30	51	2024-07-17	6	31.50	0.03	189.00	183.33	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4379	150	20	2024-07-17	8	17.00	0.02	136.00	133.28	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4380	128	26	2024-07-17	3	22.00	0.00	66.00	66.00	f	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4381	91	36	2024-07-18	8	26.50	0.03	212.00	205.64	t	3	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4382	56	7	2024-07-18	1	90.00	0.10	90.00	81.00	t	3	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4383	146	46	2024-07-18	6	25.50	0.01	153.00	151.47	t	3	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4384	89	13	2024-07-18	4	23.00	0.05	92.00	87.40	t	3	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4385	90	14	2024-07-18	10	12.00	0.06	120.00	112.80	t	3	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4386	13	51	2024-07-18	3	31.50	0.02	94.50	92.61	t	3	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4387	40	32	2024-07-18	10	48.00	0.04	480.00	460.80	t	3	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4388	144	45	2024-07-18	8	59.50	0.00	476.00	476.00	f	3	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4389	19	36	2024-07-18	7	26.50	0.09	185.50	168.81	t	3	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4390	58	7	2024-07-18	7	90.00	0.09	630.00	573.30	t	3	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4391	42	35	2024-07-18	1	63.00	0.01	63.00	62.37	t	3	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4392	137	47	2024-07-18	2	82.50	0.05	165.00	156.75	t	3	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4393	108	2	2024-07-18	10	50.00	0.07	500.00	465.00	t	3	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4394	54	4	2024-07-18	5	10.00	0.03	50.00	48.50	t	3	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4395	15	17	2024-07-18	5	80.00	0.00	400.00	400.00	f	3	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4396	52	46	2024-07-19	10	25.50	0.02	255.00	249.90	t	4	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4397	9	18	2024-07-19	10	43.00	0.07	430.00	399.90	t	4	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4398	94	5	2024-07-19	9	60.00	0.07	540.00	502.20	t	4	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4399	54	51	2024-07-19	6	31.50	0.07	189.00	175.77	t	4	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4400	30	39	2024-07-19	9	35.00	0.05	315.00	299.25	t	4	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4401	38	1	2024-07-19	6	30.00	0.06	180.00	169.20	t	4	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4402	120	22	2024-07-19	1	54.00	0.00	54.00	54.00	f	4	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4403	144	40	2024-07-19	3	13.00	0.03	39.00	37.83	t	4	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4404	62	13	2024-07-19	9	23.00	0.07	207.00	192.51	t	4	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4405	30	39	2024-07-19	2	35.00	0.05	70.00	66.50	t	4	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4406	8	46	2024-07-19	3	25.50	0.05	76.50	72.68	t	4	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4407	7	15	2024-07-20	1	70.00	0.06	70.00	65.80	t	5	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4408	106	26	2024-07-20	6	22.00	0.02	132.00	129.36	t	5	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4409	15	38	2024-07-20	3	39.00	0.06	117.00	109.98	t	5	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4410	135	24	2024-07-20	2	11.00	0.02	22.00	21.56	t	5	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4411	30	12	2024-07-20	3	44.00	0.03	132.00	128.04	t	5	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4412	96	35	2024-07-20	6	63.00	0.02	378.00	370.44	t	5	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4413	133	6	2024-07-20	2	25.00	0.06	50.00	47.00	t	5	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4414	94	53	2024-07-20	5	22.50	0.07	112.50	104.63	t	5	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4415	132	35	2024-07-20	7	63.00	0.07	441.00	410.13	t	5	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4416	77	53	2024-07-20	10	22.50	0.09	225.00	204.75	t	5	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4417	132	25	2024-07-20	6	65.00	0.05	390.00	370.50	t	5	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4418	7	38	2024-07-20	2	39.00	0.02	78.00	76.44	t	5	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4419	58	16	2024-07-20	6	26.00	0.00	156.00	156.00	f	5	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4420	29	32	2024-07-20	3	48.00	0.03	144.00	139.68	t	5	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4421	30	27	2024-07-21	4	85.00	0.03	340.00	329.80	t	6	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4422	81	13	2024-07-21	5	23.00	0.05	115.00	109.25	t	6	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4423	50	4	2024-07-21	3	10.00	0.09	30.00	27.30	t	6	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4424	45	29	2024-07-21	3	40.00	0.05	120.00	114.00	t	6	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4425	40	7	2024-07-21	10	90.00	0.02	900.00	882.00	t	6	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4426	130	19	2024-07-21	3	38.00	0.08	114.00	104.88	t	6	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4427	43	16	2024-07-21	3	26.00	0.02	78.00	76.44	t	6	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4428	47	19	2024-07-21	2	38.00	0.08	76.00	69.92	t	6	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4429	115	16	2024-07-21	1	26.00	0.05	26.00	24.70	t	6	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4430	20	13	2024-07-21	5	23.00	0.04	115.00	110.40	t	6	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4431	71	16	2024-07-21	4	26.00	0.08	104.00	95.68	t	6	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4432	103	30	2024-07-21	8	18.00	0.09	144.00	131.04	t	6	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4433	97	42	2024-07-21	4	53.00	0.09	212.00	192.92	t	6	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4434	84	22	2024-07-21	7	54.00	0.02	378.00	370.44	t	6	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4435	115	46	2024-07-21	2	25.50	0.05	51.00	48.45	t	6	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4436	125	10	2024-07-21	6	15.00	0.01	90.00	89.10	t	6	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4437	119	1	2024-07-22	8	30.00	0.05	240.00	228.00	t	0	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4438	117	5	2024-07-22	5	60.00	0.01	300.00	297.00	t	0	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4439	106	26	2024-07-22	7	22.00	0.02	154.00	150.92	t	0	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4440	129	11	2024-07-22	10	32.00	0.05	320.00	304.00	t	0	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4441	62	23	2024-07-22	9	24.00	0.08	216.00	198.72	t	0	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4442	67	7	2024-07-22	1	90.00	0.03	90.00	87.30	t	0	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4443	146	51	2024-07-22	3	31.50	0.04	94.50	90.72	t	0	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4444	113	13	2024-07-22	8	23.00	0.01	184.00	182.16	t	0	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4445	33	2	2024-07-22	7	50.00	0.02	350.00	343.00	t	0	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4446	11	48	2024-07-22	3	44.50	0.03	133.50	129.50	t	0	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4447	113	50	2024-07-22	10	17.50	0.07	175.00	162.75	t	0	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4448	104	7	2024-07-22	6	90.00	0.05	540.00	513.00	t	0	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4449	64	43	2024-07-22	4	28.00	0.07	112.00	104.16	t	0	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4450	42	6	2024-07-22	6	25.00	0.07	150.00	139.50	t	0	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4451	35	44	2024-07-22	10	10.50	0.05	105.00	99.75	t	0	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4452	24	20	2024-07-22	10	17.00	0.06	170.00	159.80	t	0	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4453	58	22	2024-07-23	6	54.00	0.07	324.00	301.32	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4454	26	49	2024-07-23	5	39.50	0.09	197.50	179.73	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4455	147	7	2024-07-23	1	90.00	0.04	90.00	86.40	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4456	29	31	2024-07-23	6	37.00	0.05	222.00	210.90	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4457	93	15	2024-07-23	2	70.00	0.01	140.00	138.60	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4458	121	52	2024-07-23	10	47.50	0.08	475.00	437.00	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4459	75	33	2024-07-23	4	21.00	0.07	84.00	78.12	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4460	99	28	2024-07-23	8	46.00	0.08	368.00	338.56	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4461	139	11	2024-07-23	5	32.00	0.07	160.00	148.80	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4462	95	44	2024-07-23	5	10.50	0.01	52.50	51.98	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4463	14	46	2024-07-23	9	25.50	0.08	229.50	211.14	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4464	135	48	2024-07-23	4	44.50	0.06	178.00	167.32	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4465	99	22	2024-07-23	7	54.00	0.09	378.00	343.98	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4466	23	4	2024-07-23	1	10.00	0.02	10.00	9.80	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4467	103	36	2024-07-23	8	26.50	0.04	212.00	203.52	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4468	123	53	2024-07-23	6	22.50	0.05	135.00	128.25	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4469	103	33	2024-07-23	4	21.00	0.08	84.00	77.28	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4470	57	51	2024-07-23	5	31.50	0.02	157.50	154.35	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4471	97	37	2024-07-23	3	88.00	0.00	264.00	264.00	f	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4472	117	48	2024-07-23	2	44.50	0.02	89.00	87.22	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4473	142	22	2024-07-24	6	54.00	0.05	324.00	307.80	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4474	129	41	2024-07-24	7	33.50	0.04	234.50	225.12	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4475	14	16	2024-07-24	5	26.00	0.02	130.00	127.40	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4476	105	51	2024-07-24	5	31.50	0.00	157.50	157.50	f	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4477	83	44	2024-07-24	9	10.50	0.01	94.50	93.55	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4478	13	15	2024-07-24	4	70.00	0.02	280.00	274.40	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4479	67	19	2024-07-24	5	38.00	0.05	190.00	180.50	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4480	44	24	2024-07-24	9	11.00	0.03	99.00	96.03	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4481	79	44	2024-07-24	9	10.50	0.01	94.50	93.55	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4482	62	51	2024-07-24	2	31.50	0.10	63.00	56.70	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4483	51	37	2024-07-24	5	88.00	0.09	440.00	400.40	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4484	35	3	2024-07-24	3	20.00	0.06	60.00	56.40	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4485	58	33	2024-07-24	9	21.00	0.07	189.00	175.77	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4486	63	12	2024-07-24	7	44.00	0.03	308.00	298.76	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4487	133	17	2024-07-24	4	80.00	0.09	320.00	291.20	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4488	23	23	2024-07-24	9	24.00	0.10	216.00	194.40	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4489	46	22	2024-07-24	7	54.00	0.01	378.00	374.22	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4490	65	32	2024-07-24	7	48.00	0.05	336.00	319.20	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4491	93	18	2024-07-24	7	43.00	0.09	301.00	273.91	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4492	104	5	2024-07-24	10	60.00	0.04	600.00	576.00	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4493	22	44	2024-07-24	10	10.50	0.00	105.00	105.00	f	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4494	119	22	2024-07-24	3	54.00	0.06	162.00	152.28	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4495	78	5	2024-07-24	6	60.00	0.03	360.00	349.20	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4496	113	51	2024-07-25	4	31.50	0.05	126.00	119.70	t	3	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4497	124	2	2024-07-25	4	50.00	0.05	200.00	190.00	t	3	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4498	47	34	2024-07-25	1	9.50	0.07	9.50	8.83	t	3	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4499	8	20	2024-07-25	10	17.00	0.01	170.00	168.30	t	3	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4500	25	7	2024-07-25	7	90.00	0.08	630.00	579.60	t	3	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4501	44	23	2024-07-25	2	24.00	0.09	48.00	43.68	t	3	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4502	48	28	2024-07-25	7	46.00	0.09	322.00	293.02	t	3	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4503	39	2	2024-07-25	3	50.00	0.05	150.00	142.50	t	3	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4504	131	42	2024-07-25	2	53.00	0.02	106.00	103.88	t	3	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4505	10	38	2024-07-25	2	39.00	0.06	78.00	73.32	t	3	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4506	18	10	2024-07-25	3	15.00	0.05	45.00	42.75	t	3	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4507	107	51	2024-07-25	9	31.50	0.01	283.50	280.67	t	3	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4508	93	8	2024-07-25	4	40.00	0.05	160.00	152.00	t	3	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4509	85	24	2024-07-25	8	11.00	0.00	88.00	88.00	f	3	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4510	109	18	2024-07-26	2	43.00	0.08	86.00	79.12	t	4	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4511	125	3	2024-07-26	3	20.00	0.08	60.00	55.20	t	4	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4512	57	39	2024-07-26	3	35.00	0.09	105.00	95.55	t	4	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4513	78	33	2024-07-26	4	21.00	0.04	84.00	80.64	t	4	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4514	66	7	2024-07-26	6	90.00	0.08	540.00	496.80	t	4	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4515	95	26	2024-07-26	4	22.00	0.02	88.00	86.24	t	4	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4516	39	21	2024-07-26	7	34.00	0.09	238.00	216.58	t	4	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4517	23	9	2024-07-26	4	36.00	0.05	144.00	136.80	t	4	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4518	49	29	2024-07-26	4	40.00	0.06	160.00	150.40	t	4	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4519	59	34	2024-07-26	1	9.50	0.04	9.50	9.12	t	4	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4520	10	13	2024-07-26	5	23.00	0.10	115.00	103.50	t	4	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4521	134	10	2024-07-26	6	15.00	0.04	90.00	86.40	t	4	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4522	49	31	2024-07-26	2	37.00	0.07	74.00	68.82	t	4	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4523	78	42	2024-07-26	10	53.00	0.03	530.00	514.10	t	4	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4524	62	14	2024-07-26	7	12.00	0.05	84.00	79.80	t	4	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4525	44	53	2024-07-26	7	22.50	0.00	157.50	157.50	f	4	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4526	21	47	2024-07-26	2	82.50	0.02	165.00	161.70	t	4	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4527	79	10	2024-07-26	10	15.00	0.06	150.00	141.00	t	4	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4528	76	45	2024-07-26	3	59.50	0.01	178.50	176.72	t	4	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4529	147	12	2024-07-26	6	44.00	0.10	264.00	237.60	t	4	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4530	132	2	2024-07-26	2	50.00	0.08	100.00	92.00	t	4	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4531	45	26	2024-07-27	3	22.00	0.08	66.00	60.72	t	5	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4532	97	30	2024-07-27	2	18.00	0.02	36.00	35.28	t	5	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4533	99	17	2024-07-27	1	80.00	0.04	80.00	76.80	t	5	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4534	33	30	2024-07-27	4	18.00	0.02	72.00	70.56	t	5	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4535	47	25	2024-07-27	2	65.00	0.05	130.00	123.50	t	5	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4536	115	23	2024-07-27	4	24.00	0.04	96.00	92.16	t	5	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4537	131	18	2024-07-27	6	43.00	0.04	258.00	247.68	t	5	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4538	130	26	2024-07-27	10	22.00	0.03	220.00	213.40	t	5	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4539	1	40	2024-07-27	7	13.00	0.03	91.00	88.27	t	5	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4540	120	49	2024-07-27	8	39.50	0.04	316.00	303.36	t	5	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4541	141	4	2024-07-27	5	10.00	0.01	50.00	49.50	t	5	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4542	117	19	2024-07-27	10	38.00	0.09	380.00	345.80	t	5	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4543	104	16	2024-07-27	1	26.00	0.07	26.00	24.18	t	5	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4544	20	24	2024-07-28	9	11.00	0.02	99.00	97.02	t	6	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4545	28	39	2024-07-28	1	35.00	0.03	35.00	33.95	t	6	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4546	4	29	2024-07-28	1	40.00	0.09	40.00	36.40	t	6	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4547	40	32	2024-07-28	7	48.00	0.07	336.00	312.48	t	6	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4548	10	5	2024-07-28	8	60.00	0.01	480.00	475.20	t	6	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4549	118	5	2024-07-28	7	60.00	0.07	420.00	390.60	t	6	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4550	144	22	2024-07-28	8	54.00	0.05	432.00	410.40	t	6	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4551	57	8	2024-07-28	7	40.00	0.09	280.00	254.80	t	6	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4552	123	17	2024-07-28	8	80.00	0.07	640.00	595.20	t	6	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4553	133	25	2024-07-28	4	65.00	0.02	260.00	254.80	t	6	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4554	29	1	2024-07-28	2	30.00	0.07	60.00	55.80	t	6	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4555	126	21	2024-07-28	7	34.00	0.06	238.00	223.72	t	6	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4556	122	45	2024-07-28	6	59.50	0.01	357.00	353.43	t	6	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4557	84	18	2024-07-28	7	43.00	0.05	301.00	285.95	t	6	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4558	44	6	2024-07-28	1	25.00	0.08	25.00	23.00	t	6	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4559	45	47	2024-07-28	6	82.50	0.10	495.00	445.50	t	6	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4560	129	33	2024-07-28	7	21.00	0.00	147.00	147.00	f	6	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4561	38	3	2024-07-29	1	20.00	0.08	20.00	18.40	t	0	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4562	59	26	2024-07-29	4	22.00	0.09	88.00	80.08	t	0	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4563	85	20	2024-07-29	4	17.00	0.07	68.00	63.24	t	0	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4564	1	43	2024-07-29	10	28.00	0.02	280.00	274.40	t	0	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4565	73	27	2024-07-29	1	85.00	0.09	85.00	77.35	t	0	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4566	9	12	2024-07-29	3	44.00	0.02	132.00	129.36	t	0	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4567	72	23	2024-07-29	6	24.00	0.09	144.00	131.04	t	0	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4568	6	40	2024-07-29	8	13.00	0.07	104.00	96.72	t	0	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4569	10	24	2024-07-30	4	11.00	0.08	44.00	40.48	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4570	80	8	2024-07-30	3	40.00	0.04	120.00	115.20	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4571	70	30	2024-07-30	6	18.00	0.09	108.00	98.28	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4572	135	2	2024-07-30	10	50.00	0.05	500.00	475.00	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4573	16	34	2024-07-30	9	9.50	0.09	85.50	77.81	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4574	11	9	2024-07-30	3	36.00	0.06	108.00	101.52	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4575	60	4	2024-07-30	7	10.00	0.01	70.00	69.30	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4576	17	6	2024-07-30	2	25.00	0.07	50.00	46.50	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4577	106	52	2024-07-30	7	47.50	0.08	332.50	305.90	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4578	38	18	2024-07-30	10	43.00	0.06	430.00	404.20	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4579	44	19	2024-07-30	10	38.00	0.08	380.00	349.60	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4580	112	5	2024-07-30	4	60.00	0.05	240.00	228.00	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4581	126	38	2024-07-30	1	39.00	0.03	39.00	37.83	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4582	28	41	2024-07-30	5	33.50	0.05	167.50	159.13	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4583	99	18	2024-07-30	7	43.00	0.10	301.00	270.90	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4584	86	12	2024-07-30	2	44.00	0.02	88.00	86.24	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4585	35	17	2024-07-30	4	80.00	0.05	320.00	304.00	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4586	92	53	2024-07-30	6	22.50	0.05	135.00	128.25	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4587	136	46	2024-07-30	5	25.50	0.02	127.50	124.95	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4588	63	20	2024-07-30	5	17.00	0.09	85.00	77.35	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4589	127	6	2024-07-30	2	25.00	0.06	50.00	47.00	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4590	17	13	2024-07-30	8	23.00	0.03	184.00	178.48	t	1	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4591	57	53	2024-07-31	1	22.50	0.06	22.50	21.15	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4592	139	44	2024-07-31	5	10.50	0.03	52.50	50.93	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4593	12	42	2024-07-31	1	53.00	0.09	53.00	48.23	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4594	56	25	2024-07-31	2	65.00	0.06	130.00	122.20	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4595	53	42	2024-07-31	8	53.00	0.04	424.00	407.04	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4596	102	23	2024-07-31	5	24.00	0.02	120.00	117.60	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4597	106	18	2024-07-31	3	43.00	0.01	129.00	127.71	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4598	69	45	2024-07-31	8	59.50	0.01	476.00	471.24	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4599	101	48	2024-07-31	6	44.50	0.08	267.00	245.64	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4600	52	4	2024-07-31	8	10.00	0.05	80.00	76.00	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4601	39	51	2024-07-31	3	31.50	0.04	94.50	90.72	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4602	61	27	2024-07-31	7	85.00	0.09	595.00	541.45	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4603	10	15	2024-07-31	9	70.00	0.05	630.00	598.50	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4604	31	25	2024-07-31	6	65.00	0.09	390.00	354.90	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4605	33	1	2024-07-31	5	30.00	0.03	150.00	145.50	t	2	7	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4606	80	29	2024-08-01	8	40.00	0.07	320.00	297.60	t	3	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4607	7	43	2024-08-01	2	28.00	0.02	56.00	54.88	t	3	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4608	149	9	2024-08-01	4	36.00	0.06	144.00	135.36	t	3	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4609	120	3	2024-08-01	5	20.00	0.08	100.00	92.00	t	3	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4610	130	46	2024-08-01	10	25.50	0.08	255.00	234.60	t	3	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4611	32	30	2024-08-01	9	18.00	0.00	162.00	162.00	f	3	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4612	96	33	2024-08-01	1	21.00	0.01	21.00	20.79	t	3	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4613	45	23	2024-08-01	4	24.00	0.05	96.00	91.20	t	3	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4614	85	39	2024-08-01	1	35.00	0.08	35.00	32.20	t	3	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4615	56	7	2024-08-01	6	90.00	0.03	540.00	523.80	t	3	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4616	125	32	2024-08-01	8	48.00	0.04	384.00	368.64	t	3	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4617	7	3	2024-08-01	5	20.00	0.05	100.00	95.00	t	3	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4618	78	5	2024-08-01	4	60.00	0.08	240.00	220.80	t	3	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4619	38	13	2024-08-01	7	23.00	0.02	161.00	157.78	t	3	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4620	147	38	2024-08-02	4	39.00	0.02	156.00	152.88	t	4	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4621	29	25	2024-08-02	4	65.00	0.08	260.00	239.20	t	4	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4622	57	49	2024-08-02	3	39.50	0.07	118.50	110.21	t	4	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4623	42	44	2024-08-02	6	10.50	0.08	63.00	57.96	t	4	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4624	84	12	2024-08-02	2	44.00	0.01	88.00	87.12	t	4	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4625	146	10	2024-08-02	4	15.00	0.08	60.00	55.20	t	4	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4626	59	23	2024-08-02	6	24.00	0.00	144.00	144.00	f	4	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4627	73	41	2024-08-02	4	33.50	0.08	134.00	123.28	t	4	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4628	75	50	2024-08-02	5	17.50	0.08	87.50	80.50	t	4	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4629	144	8	2024-08-02	8	40.00	0.07	320.00	297.60	t	4	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4630	56	36	2024-08-02	7	26.50	0.04	185.50	178.08	t	4	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4631	53	53	2024-08-02	3	22.50	0.02	67.50	66.15	t	4	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4632	32	46	2024-08-02	2	25.50	0.05	51.00	48.45	t	4	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4633	106	11	2024-08-02	1	32.00	0.07	32.00	29.76	t	4	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4634	7	47	2024-08-02	4	82.50	0.03	330.00	320.10	t	4	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4635	113	16	2024-08-02	7	26.00	0.02	182.00	178.36	t	4	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4636	108	4	2024-08-02	8	10.00	0.00	80.00	80.00	f	4	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4637	126	4	2024-08-03	4	10.00	0.05	40.00	38.00	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4638	106	44	2024-08-03	4	10.50	0.01	42.00	41.58	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4639	82	52	2024-08-03	3	47.50	0.03	142.50	138.23	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4640	71	14	2024-08-03	2	12.00	0.09	24.00	21.84	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4641	12	50	2024-08-03	5	17.50	0.03	87.50	84.88	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4642	13	25	2024-08-03	5	65.00	0.07	325.00	302.25	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4643	47	16	2024-08-03	8	26.00	0.01	208.00	205.92	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4644	13	20	2024-08-03	5	17.00	0.01	85.00	84.15	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4645	119	46	2024-08-03	7	25.50	0.05	178.50	169.58	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4646	77	47	2024-08-03	10	82.50	0.01	825.00	816.75	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4647	125	5	2024-08-03	3	60.00	0.09	180.00	163.80	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4648	62	29	2024-08-03	2	40.00	0.03	80.00	77.60	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4649	143	7	2024-08-03	9	90.00	0.08	810.00	745.20	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4650	99	41	2024-08-03	4	33.50	0.05	134.00	127.30	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4651	46	17	2024-08-03	9	80.00	0.08	720.00	662.40	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4652	32	36	2024-08-03	1	26.50	0.05	26.50	25.17	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4653	18	2	2024-08-03	8	50.00	0.02	400.00	392.00	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4654	37	42	2024-08-03	3	53.00	0.07	159.00	147.87	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4655	114	41	2024-08-03	4	33.50	0.05	134.00	127.30	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4656	126	35	2024-08-03	10	63.00	0.08	630.00	579.60	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4657	15	39	2024-08-03	5	35.00	0.10	175.00	157.50	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4658	89	5	2024-08-04	2	60.00	0.07	120.00	111.60	t	6	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4659	128	18	2024-08-04	4	43.00	0.03	172.00	166.84	t	6	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4660	107	10	2024-08-04	8	15.00	0.07	120.00	111.60	t	6	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4661	90	25	2024-08-04	1	65.00	0.03	65.00	63.05	t	6	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4662	119	14	2024-08-04	7	12.00	0.10	84.00	75.60	t	6	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4663	87	38	2024-08-04	9	39.00	0.02	351.00	343.98	t	6	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4664	101	49	2024-08-04	9	39.50	0.01	355.50	351.95	t	6	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4665	147	47	2024-08-04	5	82.50	0.09	412.50	375.38	t	6	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4666	125	24	2024-08-04	3	11.00	0.08	33.00	30.36	t	6	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4667	72	46	2024-08-04	7	25.50	0.01	178.50	176.72	t	6	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4668	63	24	2024-08-04	3	11.00	0.04	33.00	31.68	t	6	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4669	147	4	2024-08-04	5	10.00	0.06	50.00	47.00	t	6	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4670	9	45	2024-08-05	8	59.50	0.10	476.00	428.40	t	0	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4671	13	4	2024-08-05	4	10.00	0.05	40.00	38.00	t	0	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4672	74	37	2024-08-05	6	88.00	0.07	528.00	491.04	t	0	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4673	7	47	2024-08-05	4	82.50	0.10	330.00	297.00	t	0	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4674	25	53	2024-08-05	8	22.50	0.10	180.00	162.00	t	0	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4675	119	38	2024-08-05	3	39.00	0.10	117.00	105.30	t	0	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4676	16	33	2024-08-05	3	21.00	0.02	63.00	61.74	t	0	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4677	134	19	2024-08-05	1	38.00	0.09	38.00	34.58	t	0	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4678	6	14	2024-08-05	4	12.00	0.08	48.00	44.16	t	0	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4679	74	24	2024-08-05	9	11.00	0.08	99.00	91.08	t	0	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4680	111	44	2024-08-05	4	10.50	0.08	42.00	38.64	t	0	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4681	147	7	2024-08-05	7	90.00	0.05	630.00	598.50	t	0	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4682	22	19	2024-08-05	1	38.00	0.06	38.00	35.72	t	0	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4683	18	19	2024-08-05	6	38.00	0.02	228.00	223.44	t	0	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4684	88	37	2024-08-05	1	88.00	0.03	88.00	85.36	t	0	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4685	16	28	2024-08-05	3	46.00	0.00	138.00	138.00	f	0	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4686	52	15	2024-08-05	8	70.00	0.01	560.00	554.40	t	0	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4687	123	34	2024-08-05	5	9.50	0.01	47.50	47.03	t	0	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4688	70	22	2024-08-05	10	54.00	0.05	540.00	513.00	t	0	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4689	117	11	2024-08-05	10	32.00	0.06	320.00	300.80	t	0	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4690	68	46	2024-08-05	4	25.50	0.07	102.00	94.86	t	0	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4691	132	22	2024-08-05	6	54.00	0.00	324.00	324.00	f	0	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4692	38	6	2024-08-05	4	25.00	0.08	100.00	92.00	t	0	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4693	87	20	2024-08-06	9	17.00	0.02	153.00	149.94	t	1	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4694	132	5	2024-08-06	4	60.00	0.08	240.00	220.80	t	1	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4695	115	2	2024-08-06	3	50.00	0.08	150.00	138.00	t	1	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4696	72	8	2024-08-06	5	40.00	0.03	200.00	194.00	t	1	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4697	14	24	2024-08-06	9	11.00	0.08	99.00	91.08	t	1	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4698	65	21	2024-08-06	10	34.00	0.01	340.00	336.60	t	1	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4699	35	3	2024-08-06	10	20.00	0.01	200.00	198.00	t	1	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4700	77	23	2024-08-06	8	24.00	0.09	192.00	174.72	t	1	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4701	6	36	2024-08-06	5	26.50	0.07	132.50	123.23	t	1	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4702	24	6	2024-08-06	5	25.00	0.03	125.00	121.25	t	1	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4703	107	52	2024-08-06	5	47.50	0.08	237.50	218.50	t	1	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4704	125	28	2024-08-06	5	46.00	0.08	230.00	211.60	t	1	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4705	105	28	2024-08-06	10	46.00	0.03	460.00	446.20	t	1	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4706	105	43	2024-08-06	7	28.00	0.07	196.00	182.28	t	1	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4707	141	33	2024-08-06	10	21.00	0.09	210.00	191.10	t	1	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4708	11	33	2024-08-06	3	21.00	0.06	63.00	59.22	t	1	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4709	90	18	2024-08-06	2	43.00	0.07	86.00	79.98	t	1	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4710	45	5	2024-08-06	1	60.00	0.01	60.00	59.40	t	1	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4711	116	25	2024-08-06	6	65.00	0.08	390.00	358.80	t	1	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4712	67	25	2024-08-07	10	65.00	0.03	650.00	630.50	t	2	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4713	20	35	2024-08-07	8	63.00	0.03	504.00	488.88	t	2	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4714	83	1	2024-08-07	3	30.00	0.01	90.00	89.10	t	2	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4715	41	53	2024-08-07	2	22.50	0.02	45.00	44.10	t	2	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4716	60	38	2024-08-07	4	39.00	0.02	156.00	152.88	t	2	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4717	50	49	2024-08-07	2	39.50	0.03	79.00	76.63	t	2	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4718	117	7	2024-08-07	5	90.00	0.09	450.00	409.50	t	2	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4719	18	43	2024-08-07	4	28.00	0.00	112.00	112.00	f	2	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4720	144	39	2024-08-07	5	35.00	0.04	175.00	168.00	t	2	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4721	126	15	2024-08-07	2	70.00	0.02	140.00	137.20	t	2	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4722	116	30	2024-08-07	10	18.00	0.08	180.00	165.60	t	2	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4723	21	10	2024-08-07	1	15.00	0.05	15.00	14.25	t	2	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4724	73	7	2024-08-07	2	90.00	0.03	180.00	174.60	t	2	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4725	90	7	2024-08-07	1	90.00	0.05	90.00	85.50	t	2	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4726	28	36	2024-08-07	10	26.50	0.04	265.00	254.40	t	2	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4727	130	53	2024-08-07	2	22.50	0.00	45.00	45.00	f	2	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4728	16	30	2024-08-07	9	18.00	0.08	162.00	149.04	t	2	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4729	86	32	2024-08-07	5	48.00	0.03	240.00	232.80	t	2	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4730	21	39	2024-08-07	8	35.00	0.01	280.00	277.20	t	2	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4731	60	19	2024-08-07	3	38.00	0.00	114.00	114.00	f	2	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4732	104	47	2024-08-07	8	82.50	0.03	660.00	640.20	t	2	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4733	106	15	2024-08-07	5	70.00	0.00	350.00	350.00	f	2	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4734	148	36	2024-08-07	2	26.50	0.10	53.00	47.70	t	2	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4735	74	23	2024-08-08	1	24.00	0.05	24.00	22.80	t	3	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4736	144	41	2024-08-08	4	33.50	0.04	134.00	128.64	t	3	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4737	77	10	2024-08-08	4	15.00	0.07	60.00	55.80	t	3	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4738	85	12	2024-08-08	10	44.00	0.04	440.00	422.40	t	3	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4739	103	43	2024-08-08	9	28.00	0.06	252.00	236.88	t	3	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4740	27	16	2024-08-08	2	26.00	0.03	52.00	50.44	t	3	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4741	128	27	2024-08-08	2	85.00	0.09	170.00	154.70	t	3	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4742	24	43	2024-08-08	3	28.00	0.07	84.00	78.12	t	3	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4743	95	39	2024-08-08	7	35.00	0.02	245.00	240.10	t	3	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4744	9	47	2024-08-08	1	82.50	0.06	82.50	77.55	t	3	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4745	9	40	2024-08-08	8	13.00	0.01	104.00	102.96	t	3	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4746	55	36	2024-08-08	5	26.50	0.01	132.50	131.18	t	3	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4747	103	28	2024-08-08	4	46.00	0.02	184.00	180.32	t	3	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4748	40	4	2024-08-09	9	10.00	0.07	90.00	83.70	t	4	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4749	133	44	2024-08-09	9	10.50	0.04	94.50	90.72	t	4	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4750	68	9	2024-08-09	5	36.00	0.07	180.00	167.40	t	4	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4751	36	22	2024-08-09	7	54.00	0.02	378.00	370.44	t	4	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4752	8	35	2024-08-09	9	63.00	0.05	567.00	538.65	t	4	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4753	71	34	2024-08-09	2	9.50	0.05	19.00	18.05	t	4	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4754	108	18	2024-08-09	7	43.00	0.04	301.00	288.96	t	4	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4755	125	37	2024-08-09	8	88.00	0.05	704.00	668.80	t	4	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4756	49	52	2024-08-09	1	47.50	0.06	47.50	44.65	t	4	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4757	139	23	2024-08-10	10	24.00	0.03	240.00	232.80	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4758	97	17	2024-08-10	2	80.00	0.03	160.00	155.20	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4759	2	28	2024-08-10	7	46.00	0.10	322.00	289.80	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4760	19	22	2024-08-10	5	54.00	0.06	270.00	253.80	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4761	61	22	2024-08-10	7	54.00	0.09	378.00	343.98	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4762	116	5	2024-08-10	8	60.00	0.07	480.00	446.40	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4763	120	1	2024-08-10	2	30.00	0.07	60.00	55.80	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4764	17	15	2024-08-10	8	70.00	0.05	560.00	532.00	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4765	145	7	2024-08-10	8	90.00	0.06	720.00	676.80	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4766	29	15	2024-08-10	4	70.00	0.02	280.00	274.40	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4767	60	33	2024-08-10	4	21.00	0.06	84.00	78.96	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4768	19	42	2024-08-10	8	53.00	0.04	424.00	407.04	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4769	82	5	2024-08-10	1	60.00	0.09	60.00	54.60	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4770	76	28	2024-08-10	3	46.00	0.07	138.00	128.34	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4771	78	36	2024-08-10	2	26.50	0.09	53.00	48.23	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4772	83	22	2024-08-10	4	54.00	0.06	216.00	203.04	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4773	9	23	2024-08-10	10	24.00	0.00	240.00	240.00	f	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4774	32	42	2024-08-10	2	53.00	0.01	106.00	104.94	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4775	124	12	2024-08-10	4	44.00	0.09	176.00	160.16	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4776	19	1	2024-08-10	8	30.00	0.05	240.00	228.00	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4777	150	30	2024-08-10	10	18.00	0.09	180.00	163.80	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4778	121	38	2024-08-10	9	39.00	0.09	351.00	319.41	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4779	18	2	2024-08-11	7	50.00	0.01	350.00	346.50	t	6	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4780	43	29	2024-08-11	4	40.00	0.04	160.00	153.60	t	6	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4781	72	31	2024-08-11	1	37.00	0.05	37.00	35.15	t	6	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4782	140	2	2024-08-11	6	50.00	0.08	300.00	276.00	t	6	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4783	115	30	2024-08-11	3	18.00	0.03	54.00	52.38	t	6	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4784	44	30	2024-08-11	10	18.00	0.04	180.00	172.80	t	6	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4785	77	45	2024-08-11	5	59.50	0.05	297.50	282.63	t	6	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4786	147	12	2024-08-11	8	44.00	0.09	352.00	320.32	t	6	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4787	4	7	2024-08-11	1	90.00	0.02	90.00	88.20	t	6	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4788	125	35	2024-08-11	9	63.00	0.03	567.00	549.99	t	6	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4789	13	40	2024-08-11	6	13.00	0.07	78.00	72.54	t	6	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4790	61	23	2024-08-11	2	24.00	0.01	48.00	47.52	t	6	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4791	109	24	2024-08-11	2	11.00	0.09	22.00	20.02	t	6	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4792	108	32	2024-08-11	1	48.00	0.06	48.00	45.12	t	6	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4793	111	26	2024-08-11	10	22.00	0.10	220.00	198.00	t	6	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4794	19	6	2024-08-12	9	25.00	0.08	225.00	207.00	t	0	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4795	140	30	2024-08-12	5	18.00	0.03	90.00	87.30	t	0	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4796	30	8	2024-08-12	5	40.00	0.05	200.00	190.00	t	0	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4797	122	33	2024-08-12	5	21.00	0.05	105.00	99.75	t	0	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4798	66	42	2024-08-12	9	53.00	0.08	477.00	438.84	t	0	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4799	29	39	2024-08-12	8	35.00	0.05	280.00	266.00	t	0	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4800	49	37	2024-08-12	3	88.00	0.04	264.00	253.44	t	0	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4801	138	42	2024-08-12	1	53.00	0.06	53.00	49.82	t	0	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4802	69	7	2024-08-12	1	90.00	0.06	90.00	84.60	t	0	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4803	42	5	2024-08-12	1	60.00	0.05	60.00	57.00	t	0	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4804	120	42	2024-08-12	8	53.00	0.09	424.00	385.84	t	0	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4805	75	35	2024-08-12	4	63.00	0.03	252.00	244.44	t	0	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4806	112	38	2024-08-12	10	39.00	0.06	390.00	366.60	t	0	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4807	73	18	2024-08-13	5	43.00	0.08	215.00	197.80	t	1	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4808	6	22	2024-08-13	5	54.00	0.09	270.00	245.70	t	1	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4809	99	25	2024-08-13	10	65.00	0.07	650.00	604.50	t	1	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4810	49	37	2024-08-13	1	88.00	0.03	88.00	85.36	t	1	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4811	19	49	2024-08-13	10	39.50	0.00	395.00	395.00	f	1	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4812	7	25	2024-08-13	3	65.00	0.05	195.00	185.25	t	1	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4813	115	23	2024-08-13	9	24.00	0.09	216.00	196.56	t	1	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4814	110	17	2024-08-13	6	80.00	0.07	480.00	446.40	t	1	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4815	11	42	2024-08-13	4	53.00	0.03	212.00	205.64	t	1	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4816	139	21	2024-08-13	8	34.00	0.05	272.00	258.40	t	1	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4817	108	36	2024-08-13	6	26.50	0.04	159.00	152.64	t	1	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4818	43	31	2024-08-13	5	37.00	0.01	185.00	183.15	t	1	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4819	67	2	2024-08-13	3	50.00	0.05	150.00	142.50	t	1	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4820	33	40	2024-08-13	10	13.00	0.06	130.00	122.20	t	1	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4821	102	15	2024-08-13	10	70.00	0.03	700.00	679.00	t	1	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4822	134	5	2024-08-13	5	60.00	0.09	300.00	273.00	t	1	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4823	94	7	2024-08-13	9	90.00	0.10	810.00	729.00	t	1	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4824	122	11	2024-08-14	6	32.00	0.07	192.00	178.56	t	2	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4825	13	28	2024-08-14	5	46.00	0.07	230.00	213.90	t	2	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4826	95	19	2024-08-14	5	38.00	0.02	190.00	186.20	t	2	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4827	41	6	2024-08-14	2	25.00	0.04	50.00	48.00	t	2	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4828	77	29	2024-08-14	4	40.00	0.00	160.00	160.00	f	2	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4829	26	36	2024-08-14	5	26.50	0.09	132.50	120.58	t	2	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4830	37	44	2024-08-14	4	10.50	0.03	42.00	40.74	t	2	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4831	90	2	2024-08-14	5	50.00	0.02	250.00	245.00	t	2	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4832	69	21	2024-08-14	5	34.00	0.09	170.00	154.70	t	2	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4833	82	32	2024-08-14	9	48.00	0.04	432.00	414.72	t	2	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4834	9	41	2024-08-14	3	33.50	0.04	100.50	96.48	t	2	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4835	40	40	2024-08-14	9	13.00	0.09	117.00	106.47	t	2	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4836	110	53	2024-08-14	6	22.50	0.01	135.00	133.65	t	2	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4837	108	7	2024-08-14	9	90.00	0.06	810.00	761.40	t	2	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4838	59	31	2024-08-14	5	37.00	0.04	185.00	177.60	t	2	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4839	101	11	2024-08-14	6	32.00	0.03	192.00	186.24	t	2	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4840	21	46	2024-08-14	10	25.50	0.03	255.00	247.35	t	2	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4841	69	14	2024-08-14	9	12.00	0.09	108.00	98.28	t	2	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4842	74	24	2024-08-14	10	11.00	0.02	110.00	107.80	t	2	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4843	120	7	2024-08-14	9	90.00	0.06	810.00	761.40	t	2	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4844	85	33	2024-08-14	2	21.00	0.02	42.00	41.16	t	2	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4845	46	2	2024-08-15	3	50.00	0.03	150.00	145.50	t	3	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4846	33	53	2024-08-15	10	22.50	0.01	225.00	222.75	t	3	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4847	52	26	2024-08-15	3	22.00	0.04	66.00	63.36	t	3	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4848	2	23	2024-08-15	2	24.00	0.02	48.00	47.04	t	3	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4849	55	24	2024-08-15	7	11.00	0.03	77.00	74.69	t	3	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4850	114	17	2024-08-15	3	80.00	0.05	240.00	228.00	t	3	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4851	112	34	2024-08-15	1	9.50	0.08	9.50	8.74	t	3	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4852	94	36	2024-08-15	2	26.50	0.02	53.00	51.94	t	3	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4853	34	4	2024-08-15	2	10.00	0.06	20.00	18.80	t	3	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4854	143	17	2024-08-15	3	80.00	0.01	240.00	237.60	t	3	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4855	134	53	2024-08-15	8	22.50	0.01	180.00	178.20	t	3	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4856	49	14	2024-08-15	9	12.00	0.04	108.00	103.68	t	3	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4857	122	22	2024-08-15	5	54.00	0.08	270.00	248.40	t	3	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4858	125	48	2024-08-16	3	44.50	0.02	133.50	130.83	t	4	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4859	150	40	2024-08-16	10	13.00	0.09	130.00	118.30	t	4	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4860	107	14	2024-08-16	3	12.00	0.00	36.00	36.00	f	4	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4861	27	2	2024-08-16	8	50.00	0.02	400.00	392.00	t	4	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4862	76	27	2024-08-16	5	85.00	0.03	425.00	412.25	t	4	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4863	103	31	2024-08-16	5	37.00	0.10	185.00	166.50	t	4	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4864	139	2	2024-08-16	8	50.00	0.01	400.00	396.00	t	4	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4865	3	23	2024-08-16	10	24.00	0.07	240.00	223.20	t	4	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4866	19	39	2024-08-16	9	35.00	0.04	315.00	302.40	t	4	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4867	112	41	2024-08-16	4	33.50	0.08	134.00	123.28	t	4	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4868	72	13	2024-08-16	6	23.00	0.07	138.00	128.34	t	4	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4869	30	35	2024-08-16	4	63.00	0.07	252.00	234.36	t	4	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4870	47	5	2024-08-16	6	60.00	0.09	360.00	327.60	t	4	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4871	40	42	2024-08-16	4	53.00	0.07	212.00	197.16	t	4	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4872	110	14	2024-08-16	5	12.00	0.09	60.00	54.60	t	4	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4873	36	44	2024-08-16	7	10.50	0.08	73.50	67.62	t	4	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4874	138	44	2024-08-16	6	10.50	0.05	63.00	59.85	t	4	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4875	52	5	2024-08-16	9	60.00	0.04	540.00	518.40	t	4	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4876	59	30	2024-08-16	8	18.00	0.05	144.00	136.80	t	4	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4877	57	25	2024-08-16	3	65.00	0.06	195.00	183.30	t	4	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4878	98	42	2024-08-16	6	53.00	0.08	318.00	292.56	t	4	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4879	118	2	2024-08-17	8	50.00	0.07	400.00	372.00	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4880	137	10	2024-08-17	2	15.00	0.09	30.00	27.30	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4881	77	52	2024-08-17	8	47.50	0.01	380.00	376.20	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4882	140	21	2024-08-17	4	34.00	0.06	136.00	127.84	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4883	114	38	2024-08-17	6	39.00	0.09	234.00	212.94	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4884	77	51	2024-08-17	6	31.50	0.06	189.00	177.66	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4885	19	46	2024-08-17	6	25.50	0.07	153.00	142.29	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4886	113	45	2024-08-17	3	59.50	0.09	178.50	162.44	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4887	36	39	2024-08-17	6	35.00	0.02	210.00	205.80	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4888	91	23	2024-08-17	9	24.00	0.08	216.00	198.72	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4889	2	41	2024-08-17	6	33.50	0.08	201.00	184.92	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4890	14	53	2024-08-17	1	22.50	0.02	22.50	22.05	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4891	111	26	2024-08-17	1	22.00	0.06	22.00	20.68	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4892	3	37	2024-08-17	5	88.00	0.05	440.00	418.00	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4893	99	9	2024-08-17	8	36.00	0.07	288.00	267.84	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4894	56	32	2024-08-17	1	48.00	0.07	48.00	44.64	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4895	130	15	2024-08-18	7	70.00	0.03	490.00	475.30	t	6	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4896	67	15	2024-08-18	10	70.00	0.08	700.00	644.00	t	6	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4897	38	7	2024-08-18	2	90.00	0.07	180.00	167.40	t	6	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4898	81	15	2024-08-18	4	70.00	0.06	280.00	263.20	t	6	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4899	72	26	2024-08-18	1	22.00	0.00	22.00	22.00	f	6	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4900	2	5	2024-08-18	8	60.00	0.07	480.00	446.40	t	6	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4901	11	15	2024-08-18	1	70.00	0.08	70.00	64.40	t	6	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4902	59	13	2024-08-18	1	23.00	0.07	23.00	21.39	t	6	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4903	94	24	2024-08-18	6	11.00	0.08	66.00	60.72	t	6	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4904	137	33	2024-08-18	1	21.00	0.07	21.00	19.53	t	6	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4905	110	17	2024-08-18	5	80.00	0.06	400.00	376.00	t	6	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4906	131	11	2024-08-18	8	32.00	0.00	256.00	256.00	f	6	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4907	72	24	2024-08-19	10	11.00	0.07	110.00	102.30	t	0	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4908	90	18	2024-08-19	8	43.00	0.02	344.00	337.12	t	0	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4909	93	12	2024-08-19	5	44.00	0.01	220.00	217.80	t	0	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4910	99	40	2024-08-19	9	13.00	0.03	117.00	113.49	t	0	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4911	27	10	2024-08-19	9	15.00	0.09	135.00	122.85	t	0	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4912	16	24	2024-08-19	2	11.00	0.06	22.00	20.68	t	0	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4913	24	51	2024-08-19	1	31.50	0.03	31.50	30.56	t	0	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4914	4	2	2024-08-19	6	50.00	0.01	300.00	297.00	t	0	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4915	112	1	2024-08-19	3	30.00	0.10	90.00	81.00	t	0	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4916	97	31	2024-08-19	5	37.00	0.02	185.00	181.30	t	0	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4917	55	52	2024-08-19	6	47.50	0.10	285.00	256.50	t	0	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4918	52	24	2024-08-19	1	11.00	0.02	11.00	10.78	t	0	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4919	121	30	2024-08-19	6	18.00	0.02	108.00	105.84	t	0	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4920	135	43	2024-08-19	8	28.00	0.09	224.00	203.84	t	0	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4921	119	1	2024-08-19	1	30.00	0.06	30.00	28.20	t	0	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4922	30	27	2024-08-19	8	85.00	0.07	680.00	632.40	t	0	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4923	145	18	2024-08-19	7	43.00	0.01	301.00	297.99	t	0	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4924	144	3	2024-08-19	2	20.00	0.06	40.00	37.60	t	0	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4925	61	15	2024-08-19	1	70.00	0.05	70.00	66.50	t	0	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4926	129	50	2024-08-20	8	17.50	0.06	140.00	131.60	t	1	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4927	13	11	2024-08-20	5	32.00	0.09	160.00	145.60	t	1	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4928	124	51	2024-08-20	2	31.50	0.07	63.00	58.59	t	1	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4929	133	6	2024-08-20	1	25.00	0.07	25.00	23.25	t	1	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4930	59	20	2024-08-20	7	17.00	0.05	119.00	113.05	t	1	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4931	1	29	2024-08-20	10	40.00	0.07	400.00	372.00	t	1	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4932	33	21	2024-08-20	10	34.00	0.09	340.00	309.40	t	1	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4933	18	48	2024-08-20	10	44.50	0.04	445.00	427.20	t	1	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4934	122	30	2024-08-20	8	18.00	0.06	144.00	135.36	t	1	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4935	135	22	2024-08-20	6	54.00	0.09	324.00	294.84	t	1	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4936	101	17	2024-08-20	9	80.00	0.07	720.00	669.60	t	1	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4937	133	43	2024-08-20	2	28.00	0.05	56.00	53.20	t	1	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4938	3	33	2024-08-20	2	21.00	0.08	42.00	38.64	t	1	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4939	150	18	2024-08-20	5	43.00	0.08	215.00	197.80	t	1	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4940	67	9	2024-08-20	2	36.00	0.03	72.00	69.84	t	1	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4941	117	44	2024-08-20	4	10.50	0.03	42.00	40.74	t	1	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4942	104	15	2024-08-20	7	70.00	0.04	490.00	470.40	t	1	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4943	130	16	2024-08-21	7	26.00	0.04	182.00	174.72	t	2	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4944	57	30	2024-08-21	6	18.00	0.09	108.00	98.28	t	2	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4945	73	31	2024-08-21	2	37.00	0.00	74.00	74.00	f	2	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4946	131	12	2024-08-21	6	44.00	0.02	264.00	258.72	t	2	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4947	87	7	2024-08-21	4	90.00	0.09	360.00	327.60	t	2	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4948	16	41	2024-08-21	7	33.50	0.08	234.50	215.74	t	2	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4949	44	49	2024-08-21	4	39.50	0.01	158.00	156.42	t	2	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4950	37	25	2024-08-21	3	65.00	0.02	195.00	191.10	t	2	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4951	67	38	2024-08-21	3	39.00	0.03	117.00	113.49	t	2	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4952	11	46	2024-08-21	4	25.50	0.01	102.00	100.98	t	2	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4953	59	9	2024-08-21	10	36.00	0.04	360.00	345.60	t	2	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4954	89	45	2024-08-21	9	59.50	0.08	535.50	492.66	t	2	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4955	65	51	2024-08-21	1	31.50	0.03	31.50	30.56	t	2	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4956	93	1	2024-08-21	6	30.00	0.01	180.00	178.20	t	2	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4957	37	33	2024-08-21	1	21.00	0.06	21.00	19.74	t	2	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4958	98	26	2024-08-21	6	22.00	0.03	132.00	128.04	t	2	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4959	59	21	2024-08-21	7	34.00	0.07	238.00	221.34	t	2	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4960	86	8	2024-08-21	1	40.00	0.08	40.00	36.80	t	2	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4961	4	11	2024-08-21	8	32.00	0.08	256.00	235.52	t	2	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4962	64	51	2024-08-21	5	31.50	0.03	157.50	152.78	t	2	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4963	23	18	2024-08-21	1	43.00	0.05	43.00	40.85	t	2	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4964	112	4	2024-08-21	10	10.00	0.07	100.00	93.00	t	2	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4965	32	48	2024-08-21	2	44.50	0.09	89.00	80.99	t	2	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4966	114	32	2024-08-22	5	48.00	0.10	240.00	216.00	t	3	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4967	89	21	2024-08-22	6	34.00	0.06	204.00	191.76	t	3	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4968	18	32	2024-08-22	10	48.00	0.02	480.00	470.40	t	3	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4969	83	8	2024-08-22	6	40.00	0.02	240.00	235.20	t	3	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4970	130	10	2024-08-22	2	15.00	0.10	30.00	27.00	t	3	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4971	129	11	2024-08-22	1	32.00	0.09	32.00	29.12	t	3	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4972	130	51	2024-08-22	8	31.50	0.07	252.00	234.36	t	3	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4973	136	38	2024-08-22	8	39.00	0.10	312.00	280.80	t	3	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4974	78	1	2024-08-22	6	30.00	0.02	180.00	176.40	t	3	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4975	68	11	2024-08-22	7	32.00	0.03	224.00	217.28	t	3	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4976	114	3	2024-08-22	10	20.00	0.08	200.00	184.00	t	3	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4977	52	32	2024-08-22	3	48.00	0.06	144.00	135.36	t	3	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4978	4	29	2024-08-23	7	40.00	0.09	280.00	254.80	t	4	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4979	107	2	2024-08-23	3	50.00	0.05	150.00	142.50	t	4	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4980	66	45	2024-08-23	5	59.50	0.09	297.50	270.73	t	4	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4981	115	8	2024-08-23	3	40.00	0.02	120.00	117.60	t	4	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4982	54	11	2024-08-23	3	32.00	0.05	96.00	91.20	t	4	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4983	46	19	2024-08-23	7	38.00	0.10	266.00	239.40	t	4	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4984	81	36	2024-08-23	10	26.50	0.08	265.00	243.80	t	4	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4985	81	42	2024-08-23	10	53.00	0.03	530.00	514.10	t	4	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4986	1	10	2024-08-24	8	15.00	0.03	120.00	116.40	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4987	57	37	2024-08-24	8	88.00	0.05	704.00	668.80	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4988	130	30	2024-08-24	1	18.00	0.09	18.00	16.38	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4989	86	4	2024-08-24	7	10.00	0.08	70.00	64.40	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4990	72	16	2024-08-24	3	26.00	0.03	78.00	75.66	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4991	118	16	2024-08-24	2	26.00	0.02	52.00	50.96	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4992	122	52	2024-08-24	9	47.50	0.01	427.50	423.23	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4993	138	38	2024-08-24	7	39.00	0.02	273.00	267.54	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4994	28	29	2024-08-24	1	40.00	0.05	40.00	38.00	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4995	12	38	2024-08-24	4	39.00	0.05	156.00	148.20	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4996	119	24	2024-08-24	1	11.00	0.09	11.00	10.01	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4997	132	35	2024-08-24	3	63.00	0.06	189.00	177.66	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4998	122	1	2024-08-24	3	30.00	0.07	90.00	83.70	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
4999	31	4	2024-08-24	1	10.00	0.05	10.00	9.50	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5000	108	3	2024-08-24	5	20.00	0.01	100.00	99.00	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5001	44	28	2024-08-24	2	46.00	0.01	92.00	91.08	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5002	142	7	2024-08-24	8	90.00	0.02	720.00	705.60	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5003	133	15	2024-08-24	1	70.00	0.04	70.00	67.20	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5004	41	29	2024-08-24	1	40.00	0.01	40.00	39.60	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5005	91	20	2024-08-24	5	17.00	0.06	85.00	79.90	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5006	9	39	2024-08-24	3	35.00	0.07	105.00	97.65	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5007	86	11	2024-08-24	7	32.00	0.01	224.00	221.76	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5008	8	6	2024-08-24	1	25.00	0.04	25.00	24.00	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5009	16	14	2024-08-24	8	12.00	0.04	96.00	92.16	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5010	53	14	2024-08-24	8	12.00	0.08	96.00	88.32	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5011	7	31	2024-08-25	4	37.00	0.03	148.00	143.56	t	6	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5012	92	16	2024-08-25	5	26.00	0.07	130.00	120.90	t	6	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5013	114	52	2024-08-25	7	47.50	0.02	332.50	325.85	t	6	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5014	90	20	2024-08-25	9	17.00	0.04	153.00	146.88	t	6	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5015	136	32	2024-08-25	5	48.00	0.08	240.00	220.80	t	6	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5016	10	20	2024-08-25	9	17.00	0.07	153.00	142.29	t	6	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5017	66	14	2024-08-25	1	12.00	0.04	12.00	11.52	t	6	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5018	105	7	2024-08-25	4	90.00	0.10	360.00	324.00	t	6	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5019	57	17	2024-08-25	5	80.00	0.02	400.00	392.00	t	6	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5020	14	38	2024-08-25	3	39.00	0.03	117.00	113.49	t	6	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5021	149	36	2024-08-25	9	26.50	0.10	238.50	214.65	t	6	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5022	34	33	2024-08-25	10	21.00	0.10	210.00	189.00	t	6	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5023	124	7	2024-08-25	4	90.00	0.05	360.00	342.00	t	6	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5024	108	52	2024-08-26	6	47.50	0.02	285.00	279.30	t	0	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5025	146	3	2024-08-26	4	20.00	0.00	80.00	80.00	f	0	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5026	97	38	2024-08-26	4	39.00	0.05	156.00	148.20	t	0	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5027	48	4	2024-08-26	7	10.00	0.10	70.00	63.00	t	0	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5028	119	19	2024-08-26	1	38.00	0.05	38.00	36.10	t	0	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5029	87	45	2024-08-26	4	59.50	0.00	238.00	238.00	f	0	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5030	150	14	2024-08-26	1	12.00	0.02	12.00	11.76	t	0	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5031	131	12	2024-08-26	9	44.00	0.04	396.00	380.16	t	0	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5032	100	35	2024-08-26	5	63.00	0.02	315.00	308.70	t	0	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5033	67	33	2024-08-26	7	21.00	0.08	147.00	135.24	t	0	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5034	78	32	2024-08-26	1	48.00	0.03	48.00	46.56	t	0	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5035	58	18	2024-08-26	6	43.00	0.06	258.00	242.52	t	0	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5036	26	7	2024-08-26	8	90.00	0.08	720.00	662.40	t	0	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5037	140	28	2024-08-26	4	46.00	0.04	184.00	176.64	t	0	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5038	54	44	2024-08-26	9	10.50	0.04	94.50	90.72	t	0	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5039	93	25	2024-08-26	6	65.00	0.08	390.00	358.80	t	0	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5040	34	3	2024-08-27	2	20.00	0.07	40.00	37.20	t	1	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5041	64	48	2024-08-27	5	44.50	0.06	222.50	209.15	t	1	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5042	6	16	2024-08-27	1	26.00	0.04	26.00	24.96	t	1	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5043	72	23	2024-08-27	2	24.00	0.03	48.00	46.56	t	1	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5044	99	26	2024-08-27	10	22.00	0.03	220.00	213.40	t	1	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5045	102	9	2024-08-27	9	36.00	0.10	324.00	291.60	t	1	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5046	58	16	2024-08-27	3	26.00	0.06	78.00	73.32	t	1	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5047	123	30	2024-08-27	8	18.00	0.03	144.00	139.68	t	1	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5048	16	47	2024-08-27	5	82.50	0.08	412.50	379.50	t	1	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5049	56	52	2024-08-27	8	47.50	0.03	380.00	368.60	t	1	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5050	144	15	2024-08-27	1	70.00	0.03	70.00	67.90	t	1	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5051	92	23	2024-08-27	2	24.00	0.09	48.00	43.68	t	1	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5052	50	52	2024-08-27	10	47.50	0.07	475.00	441.75	t	1	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5053	120	43	2024-08-27	7	28.00	0.08	196.00	180.32	t	1	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5054	146	43	2024-08-27	1	28.00	0.09	28.00	25.48	t	1	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5055	108	14	2024-08-27	3	12.00	0.04	36.00	34.56	t	1	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5056	38	17	2024-08-27	6	80.00	0.03	480.00	465.60	t	1	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5057	146	34	2024-08-27	3	9.50	0.10	28.50	25.65	t	1	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5058	39	4	2024-08-27	2	10.00	0.03	20.00	19.40	t	1	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5059	100	10	2024-08-27	10	15.00	0.02	150.00	147.00	t	1	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5060	91	52	2024-08-28	8	47.50	0.02	380.00	372.40	t	2	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5061	135	33	2024-08-28	1	21.00	0.00	21.00	21.00	f	2	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5062	134	12	2024-08-28	6	44.00	0.05	264.00	250.80	t	2	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5063	10	1	2024-08-28	7	30.00	0.03	210.00	203.70	t	2	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5064	69	4	2024-08-28	9	10.00	0.00	90.00	90.00	f	2	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5065	10	22	2024-08-28	7	54.00	0.07	378.00	351.54	t	2	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5066	123	25	2024-08-28	4	65.00	0.08	260.00	239.20	t	2	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5067	77	23	2024-08-28	6	24.00	0.01	144.00	142.56	t	2	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5068	86	53	2024-08-28	4	22.50	0.05	90.00	85.50	t	2	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5069	28	22	2024-08-28	6	54.00	0.04	324.00	311.04	t	2	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5070	148	17	2024-08-28	3	80.00	0.03	240.00	232.80	t	2	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5071	58	50	2024-08-28	1	17.50	0.07	17.50	16.28	t	2	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5072	80	38	2024-08-28	6	39.00	0.09	234.00	212.94	t	2	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5073	66	40	2024-08-28	2	13.00	0.00	26.00	26.00	f	2	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5074	3	51	2024-08-28	8	31.50	0.09	252.00	229.32	t	2	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5075	84	25	2024-08-28	1	65.00	0.09	65.00	59.15	t	2	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5076	77	52	2024-08-28	8	47.50	0.06	380.00	357.20	t	2	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5077	122	32	2024-08-28	6	48.00	0.08	288.00	264.96	t	2	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5078	77	26	2024-08-29	9	22.00	0.06	198.00	186.12	t	3	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5079	85	30	2024-08-29	10	18.00	0.02	180.00	176.40	t	3	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5080	32	37	2024-08-29	6	88.00	0.05	528.00	501.60	t	3	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5081	44	44	2024-08-29	3	10.50	0.04	31.50	30.24	t	3	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5082	27	40	2024-08-29	6	13.00	0.07	78.00	72.54	t	3	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5083	101	16	2024-08-29	8	26.00	0.08	208.00	191.36	t	3	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5084	1	37	2024-08-29	3	88.00	0.05	264.00	250.80	t	3	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5085	105	43	2024-08-29	2	28.00	0.08	56.00	51.52	t	3	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5086	52	28	2024-08-29	4	46.00	0.09	184.00	167.44	t	3	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5087	109	34	2024-08-29	10	9.50	0.07	95.00	88.35	t	3	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5088	77	53	2024-08-29	2	22.50	0.02	45.00	44.10	t	3	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5089	83	52	2024-08-29	7	47.50	0.03	332.50	322.53	t	3	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5090	142	20	2024-08-29	1	17.00	0.08	17.00	15.64	t	3	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5091	115	8	2024-08-29	7	40.00	0.08	280.00	257.60	t	3	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5092	38	16	2024-08-29	9	26.00	0.06	234.00	219.96	t	3	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5093	24	38	2024-08-29	3	39.00	0.09	117.00	106.47	t	3	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5094	72	21	2024-08-29	10	34.00	0.08	340.00	312.80	t	3	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5095	132	49	2024-08-29	3	39.50	0.04	118.50	113.76	t	3	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5096	98	28	2024-08-29	3	46.00	0.05	138.00	131.10	t	3	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5097	83	31	2024-08-30	2	37.00	0.07	74.00	68.82	t	4	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5098	49	40	2024-08-30	6	13.00	0.08	78.00	71.76	t	4	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5099	69	38	2024-08-30	3	39.00	0.04	117.00	112.32	t	4	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5100	34	17	2024-08-30	8	80.00	0.05	640.00	608.00	t	4	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5101	114	6	2024-08-30	7	25.00	0.04	175.00	168.00	t	4	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5102	125	31	2024-08-30	10	37.00	0.09	370.00	336.70	t	4	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5103	120	20	2024-08-30	10	17.00	0.08	170.00	156.40	t	4	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5104	103	17	2024-08-30	3	80.00	0.10	240.00	216.00	t	4	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5105	148	48	2024-08-30	7	44.50	0.06	311.50	292.81	t	4	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5106	122	14	2024-08-30	9	12.00	0.07	108.00	100.44	t	4	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5107	118	12	2024-08-30	9	44.00	0.02	396.00	388.08	t	4	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5108	147	32	2024-08-30	7	48.00	0.02	336.00	329.28	t	4	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5109	42	47	2024-08-30	7	82.50	0.04	577.50	554.40	t	4	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5110	13	38	2024-08-30	1	39.00	0.07	39.00	36.27	t	4	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5111	115	39	2024-08-30	10	35.00	0.03	350.00	339.50	t	4	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5112	3	41	2024-08-30	3	33.50	0.08	100.50	92.46	t	4	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5113	76	40	2024-08-31	1	13.00	0.09	13.00	11.83	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5114	69	31	2024-08-31	2	37.00	0.10	74.00	66.60	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5115	96	22	2024-08-31	4	54.00	0.07	216.00	200.88	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5116	71	37	2024-08-31	3	88.00	0.07	264.00	245.52	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5117	28	46	2024-08-31	1	25.50	0.09	25.50	23.21	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5118	67	8	2024-08-31	2	40.00	0.07	80.00	74.40	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5119	19	18	2024-08-31	3	43.00	0.06	129.00	121.26	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5120	141	46	2024-08-31	3	25.50	0.01	76.50	75.74	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5121	1	17	2024-08-31	6	80.00	0.07	480.00	446.40	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5122	109	20	2024-08-31	4	17.00	0.07	68.00	63.24	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5123	112	40	2024-08-31	1	13.00	0.02	13.00	12.74	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5124	130	6	2024-08-31	6	25.00	0.07	150.00	139.50	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5125	50	15	2024-08-31	6	70.00	0.10	420.00	378.00	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5126	119	32	2024-08-31	9	48.00	0.04	432.00	414.72	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5127	32	40	2024-08-31	3	13.00	0.07	39.00	36.27	t	5	8	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5128	70	48	2024-09-01	8	44.50	0.05	356.00	338.20	t	6	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5129	101	15	2024-09-01	3	70.00	0.02	210.00	205.80	t	6	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5130	19	38	2024-09-01	9	39.00	0.10	351.00	315.90	t	6	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5131	113	49	2024-09-01	5	39.50	0.02	197.50	193.55	t	6	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5132	90	52	2024-09-01	4	47.50	0.02	190.00	186.20	t	6	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5133	68	52	2024-09-01	7	47.50	0.06	332.50	312.55	t	6	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5134	131	52	2024-09-01	8	47.50	0.01	380.00	376.20	t	6	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5135	15	40	2024-09-01	9	13.00	0.08	117.00	107.64	t	6	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5136	25	22	2024-09-01	9	54.00	0.10	486.00	437.40	t	6	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5137	5	17	2024-09-01	7	80.00	0.04	560.00	537.60	t	6	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5138	118	30	2024-09-01	10	18.00	0.07	180.00	167.40	t	6	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5139	43	3	2024-09-01	4	20.00	0.02	80.00	78.40	t	6	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5140	115	28	2024-09-01	6	46.00	0.02	276.00	270.48	t	6	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5141	37	49	2024-09-01	10	39.50	0.06	395.00	371.30	t	6	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5142	120	35	2024-09-02	5	63.00	0.09	315.00	286.65	t	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5143	75	39	2024-09-02	6	35.00	0.02	210.00	205.80	t	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5144	117	2	2024-09-02	2	50.00	0.10	100.00	90.00	t	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5145	93	25	2024-09-02	4	65.00	0.01	260.00	257.40	t	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5146	138	50	2024-09-02	9	17.50	0.04	157.50	151.20	t	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5147	118	43	2024-09-02	10	28.00	0.07	280.00	260.40	t	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5148	104	43	2024-09-02	7	28.00	0.04	196.00	188.16	t	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5149	4	6	2024-09-02	5	25.00	0.08	125.00	115.00	t	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5150	54	36	2024-09-02	9	26.50	0.03	238.50	231.35	t	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5151	149	42	2024-09-02	5	53.00	0.05	265.00	251.75	t	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5152	86	2	2024-09-02	5	50.00	0.04	250.00	240.00	t	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5153	63	9	2024-09-02	1	36.00	0.08	36.00	33.12	t	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5154	44	13	2024-09-02	9	23.00	0.03	207.00	200.79	t	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5155	22	11	2024-09-02	8	32.00	0.07	256.00	238.08	t	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5156	15	50	2024-09-02	7	17.50	0.08	122.50	112.70	t	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5157	42	5	2024-09-02	8	60.00	0.01	480.00	475.20	t	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5158	145	4	2024-09-02	4	10.00	0.04	40.00	38.40	t	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5159	113	4	2024-09-02	10	10.00	0.06	100.00	94.00	t	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5160	20	32	2024-09-02	3	48.00	0.09	144.00	131.04	t	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5161	146	22	2024-09-02	2	54.00	0.09	108.00	98.28	t	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5162	110	39	2024-09-02	5	35.00	0.02	175.00	171.50	t	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5163	7	16	2024-09-03	7	26.00	0.04	182.00	174.72	t	1	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5164	20	40	2024-09-03	9	13.00	0.03	117.00	113.49	t	1	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5165	104	14	2024-09-03	6	12.00	0.02	72.00	70.56	t	1	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5166	138	15	2024-09-03	9	70.00	0.05	630.00	598.50	t	1	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5167	4	37	2024-09-03	10	88.00	0.03	880.00	853.60	t	1	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5168	21	43	2024-09-03	10	28.00	0.05	280.00	266.00	t	1	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5169	150	29	2024-09-03	2	40.00	0.04	80.00	76.80	t	1	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5170	114	28	2024-09-03	3	46.00	0.03	138.00	133.86	t	1	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5171	77	5	2024-09-03	2	60.00	0.04	120.00	115.20	t	1	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5172	78	11	2024-09-03	3	32.00	0.02	96.00	94.08	t	1	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5173	62	20	2024-09-03	1	17.00	0.01	17.00	16.83	t	1	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5174	81	16	2024-09-03	5	26.00	0.02	130.00	127.40	t	1	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5175	51	52	2024-09-04	8	47.50	0.09	380.00	345.80	t	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5176	63	32	2024-09-04	6	48.00	0.00	288.00	288.00	f	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5177	122	45	2024-09-04	3	59.50	0.09	178.50	162.44	t	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5178	103	47	2024-09-04	2	82.50	0.04	165.00	158.40	t	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5179	83	25	2024-09-04	6	65.00	0.03	390.00	378.30	t	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5180	28	37	2024-09-04	1	88.00	0.07	88.00	81.84	t	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5181	52	50	2024-09-04	6	17.50	0.10	105.00	94.50	t	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5182	95	34	2024-09-04	9	9.50	0.02	85.50	83.79	t	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5183	126	24	2024-09-04	10	11.00	0.10	110.00	99.00	t	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5184	17	13	2024-09-04	4	23.00	0.08	92.00	84.64	t	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5185	18	30	2024-09-04	8	18.00	0.02	144.00	141.12	t	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5186	84	28	2024-09-04	1	46.00	0.07	46.00	42.78	t	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5187	28	14	2024-09-04	3	12.00	0.10	36.00	32.40	t	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5188	144	46	2024-09-04	8	25.50	0.08	204.00	187.68	t	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5189	52	51	2024-09-04	1	31.50	0.03	31.50	30.56	t	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5190	108	12	2024-09-04	7	44.00	0.04	308.00	295.68	t	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5191	117	39	2024-09-04	1	35.00	0.06	35.00	32.90	t	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5192	66	53	2024-09-04	1	22.50	0.06	22.50	21.15	t	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5193	125	15	2024-09-04	5	70.00	0.10	350.00	315.00	t	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5194	100	33	2024-09-04	1	21.00	0.10	21.00	18.90	t	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5195	15	43	2024-09-04	9	28.00	0.08	252.00	231.84	t	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5196	60	11	2024-09-04	9	32.00	0.05	288.00	273.60	t	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5197	91	13	2024-09-05	10	23.00	0.08	230.00	211.60	t	3	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5198	71	30	2024-09-05	9	18.00	0.05	162.00	153.90	t	3	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5199	48	20	2024-09-05	4	17.00	0.09	68.00	61.88	t	3	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5200	40	48	2024-09-05	5	44.50	0.09	222.50	202.48	t	3	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5201	31	25	2024-09-05	3	65.00	0.08	195.00	179.40	t	3	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5202	40	5	2024-09-05	7	60.00	0.08	420.00	386.40	t	3	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5203	93	10	2024-09-05	7	15.00	0.01	105.00	103.95	t	3	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5204	79	7	2024-09-05	7	90.00	0.02	630.00	617.40	t	3	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5205	38	29	2024-09-05	3	40.00	0.08	120.00	110.40	t	3	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5206	116	36	2024-09-05	5	26.50	0.01	132.50	131.18	t	3	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5207	59	26	2024-09-05	4	22.00	0.01	88.00	87.12	t	3	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5208	99	19	2024-09-05	2	38.00	0.02	76.00	74.48	t	3	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5209	27	15	2024-09-05	8	70.00	0.06	560.00	526.40	t	3	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5210	140	47	2024-09-05	7	82.50	0.00	577.50	577.50	f	3	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5211	60	40	2024-09-05	5	13.00	0.08	65.00	59.80	t	3	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5212	129	51	2024-09-05	8	31.50	0.01	252.00	249.48	t	3	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5213	27	15	2024-09-05	4	70.00	0.01	280.00	277.20	t	3	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5214	80	34	2024-09-06	4	9.50	0.02	38.00	37.24	t	4	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5215	41	30	2024-09-06	2	18.00	0.04	36.00	34.56	t	4	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5216	61	40	2024-09-06	3	13.00	0.03	39.00	37.83	t	4	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5217	86	45	2024-09-06	10	59.50	0.05	595.00	565.25	t	4	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5218	4	10	2024-09-06	2	15.00	0.06	30.00	28.20	t	4	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5219	14	28	2024-09-06	1	46.00	0.04	46.00	44.16	t	4	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5220	130	47	2024-09-06	3	82.50	0.09	247.50	225.23	t	4	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5221	122	42	2024-09-06	7	53.00	0.04	371.00	356.16	t	4	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5222	104	38	2024-09-06	1	39.00	0.08	39.00	35.88	t	4	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5223	59	13	2024-09-06	7	23.00	0.04	161.00	154.56	t	4	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5224	113	34	2024-09-06	3	9.50	0.02	28.50	27.93	t	4	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5225	6	15	2024-09-06	5	70.00	0.01	350.00	346.50	t	4	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5226	97	34	2024-09-06	8	9.50	0.03	76.00	73.72	t	4	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5227	56	21	2024-09-06	9	34.00	0.09	306.00	278.46	t	4	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5228	50	11	2024-09-06	2	32.00	0.02	64.00	62.72	t	4	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5229	142	32	2024-09-06	6	48.00	0.08	288.00	264.96	t	4	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5230	37	42	2024-09-06	9	53.00	0.10	477.00	429.30	t	4	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5231	44	49	2024-09-06	10	39.50	0.07	395.00	367.35	t	4	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5232	144	13	2024-09-06	2	23.00	0.07	46.00	42.78	t	4	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5233	121	36	2024-09-06	1	26.50	0.03	26.50	25.71	t	4	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5234	4	35	2024-09-06	2	63.00	0.03	126.00	122.22	t	4	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5235	44	15	2024-09-06	8	70.00	0.09	560.00	509.60	t	4	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5236	130	52	2024-09-06	8	47.50	0.04	380.00	364.80	t	4	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5237	102	5	2024-09-06	8	60.00	0.05	480.00	456.00	t	4	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5238	127	2	2024-09-07	2	50.00	0.06	100.00	94.00	t	5	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5239	60	53	2024-09-07	8	22.50	0.02	180.00	176.40	t	5	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5240	144	14	2024-09-07	8	12.00	0.04	96.00	92.16	t	5	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5241	148	17	2024-09-07	1	80.00	0.02	80.00	78.40	t	5	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5242	61	19	2024-09-07	8	38.00	0.01	304.00	300.96	t	5	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5243	76	32	2024-09-07	5	48.00	0.04	240.00	230.40	t	5	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5244	81	25	2024-09-07	3	65.00	0.02	195.00	191.10	t	5	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5245	32	9	2024-09-07	3	36.00	0.03	108.00	104.76	t	5	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5246	28	22	2024-09-07	3	54.00	0.04	162.00	155.52	t	5	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5247	64	24	2024-09-07	4	11.00	0.07	44.00	40.92	t	5	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5248	143	25	2024-09-07	6	65.00	0.09	390.00	354.90	t	5	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5249	86	45	2024-09-07	2	59.50	0.04	119.00	114.24	t	5	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5250	100	6	2024-09-07	5	25.00	0.10	125.00	112.50	t	5	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5251	6	24	2024-09-07	5	11.00	0.04	55.00	52.80	t	5	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5252	18	31	2024-09-07	8	37.00	0.07	296.00	275.28	t	5	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5253	96	25	2024-09-07	9	65.00	0.05	585.00	555.75	t	5	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5254	46	30	2024-09-07	9	18.00	0.04	162.00	155.52	t	5	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5255	7	14	2024-09-07	10	12.00	0.07	120.00	111.60	t	5	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5256	31	38	2024-09-08	3	39.00	0.04	117.00	112.32	t	6	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5257	64	34	2024-09-08	5	9.50	0.06	47.50	44.65	t	6	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5258	114	44	2024-09-08	2	10.50	0.09	21.00	19.11	t	6	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5259	142	20	2024-09-08	4	17.00	0.06	68.00	63.92	t	6	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5260	147	8	2024-09-08	7	40.00	0.02	280.00	274.40	t	6	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5261	22	11	2024-09-08	1	32.00	0.03	32.00	31.04	t	6	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5262	97	4	2024-09-08	9	10.00	0.04	90.00	86.40	t	6	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5263	25	3	2024-09-08	3	20.00	0.09	60.00	54.60	t	6	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5264	18	6	2024-09-08	5	25.00	0.02	125.00	122.50	t	6	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5265	109	39	2024-09-08	5	35.00	0.01	175.00	173.25	t	6	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5266	19	28	2024-09-08	5	46.00	0.10	230.00	207.00	t	6	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5267	54	42	2024-09-08	10	53.00	0.10	530.00	477.00	t	6	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5268	87	18	2024-09-08	3	43.00	0.08	129.00	118.68	t	6	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5269	148	44	2024-09-08	3	10.50	0.05	31.50	29.92	t	6	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5270	137	37	2024-09-08	3	88.00	0.02	264.00	258.72	t	6	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5271	104	31	2024-09-09	9	37.00	0.05	333.00	316.35	t	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5272	109	26	2024-09-09	8	22.00	0.01	176.00	174.24	t	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5273	5	27	2024-09-09	2	85.00	0.02	170.00	166.60	t	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5274	72	27	2024-09-09	4	85.00	0.08	340.00	312.80	t	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5275	45	39	2024-09-09	6	35.00	0.07	210.00	195.30	t	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5276	44	32	2024-09-09	1	48.00	0.01	48.00	47.52	t	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5277	109	17	2024-09-09	7	80.00	0.06	560.00	526.40	t	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5278	66	22	2024-09-09	8	54.00	0.04	432.00	414.72	t	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5279	9	11	2024-09-09	4	32.00	0.05	128.00	121.60	t	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5280	68	34	2024-09-09	4	9.50	0.07	38.00	35.34	t	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5281	53	15	2024-09-09	6	70.00	0.04	420.00	403.20	t	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5282	68	39	2024-09-09	1	35.00	0.02	35.00	34.30	t	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5283	34	9	2024-09-09	9	36.00	0.00	324.00	324.00	f	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5284	47	7	2024-09-10	10	90.00	0.04	900.00	864.00	t	1	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5285	97	25	2024-09-10	4	65.00	0.04	260.00	249.60	t	1	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5286	37	14	2024-09-10	10	12.00	0.06	120.00	112.80	t	1	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5287	111	40	2024-09-10	5	13.00	0.01	65.00	64.35	t	1	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5288	79	41	2024-09-10	8	33.50	0.04	268.00	257.28	t	1	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5289	141	41	2024-09-10	4	33.50	0.03	134.00	129.98	t	1	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5290	69	10	2024-09-10	9	15.00	0.06	135.00	126.90	t	1	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5291	142	19	2024-09-10	9	38.00	0.03	342.00	331.74	t	1	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5292	120	41	2024-09-10	6	33.50	0.08	201.00	184.92	t	1	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5293	64	5	2024-09-10	3	60.00	0.04	180.00	172.80	t	1	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5294	71	7	2024-09-10	5	90.00	0.06	450.00	423.00	t	1	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5295	28	20	2024-09-10	4	17.00	0.05	68.00	64.60	t	1	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5296	2	23	2024-09-10	3	24.00	0.04	72.00	69.12	t	1	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5297	74	24	2024-09-10	8	11.00	0.00	88.00	88.00	f	1	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5298	127	27	2024-09-10	6	85.00	0.08	510.00	469.20	t	1	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5299	109	3	2024-09-10	6	20.00	0.08	120.00	110.40	t	1	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5300	87	27	2024-09-10	1	85.00	0.01	85.00	84.15	t	1	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5301	94	11	2024-09-10	5	32.00	0.09	160.00	145.60	t	1	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5302	87	41	2024-09-10	2	33.50	0.05	67.00	63.65	t	1	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5303	33	30	2024-09-10	3	18.00	0.00	54.00	54.00	f	1	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5304	101	43	2024-09-10	9	28.00	0.09	252.00	229.32	t	1	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5305	76	22	2024-09-10	4	54.00	0.09	216.00	196.56	t	1	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5306	147	19	2024-09-10	9	38.00	0.00	342.00	342.00	f	1	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5307	46	37	2024-09-10	9	88.00	0.03	792.00	768.24	t	1	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5308	137	23	2024-09-11	3	24.00	0.04	72.00	69.12	t	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5309	129	22	2024-09-11	4	54.00	0.04	216.00	207.36	t	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5310	86	25	2024-09-11	5	65.00	0.03	325.00	315.25	t	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5311	98	37	2024-09-11	4	88.00	0.08	352.00	323.84	t	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5312	35	47	2024-09-11	1	82.50	0.04	82.50	79.20	t	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5313	24	12	2024-09-11	6	44.00	0.02	264.00	258.72	t	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5314	147	10	2024-09-11	7	15.00	0.05	105.00	99.75	t	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5315	35	27	2024-09-11	8	85.00	0.05	680.00	646.00	t	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5316	14	8	2024-09-11	1	40.00	0.01	40.00	39.60	t	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5317	20	15	2024-09-11	9	70.00	0.00	630.00	630.00	f	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5318	131	52	2024-09-11	7	47.50	0.02	332.50	325.85	t	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5319	148	3	2024-09-11	4	20.00	0.04	80.00	76.80	t	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5320	66	5	2024-09-11	7	60.00	0.05	420.00	399.00	t	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5321	148	31	2024-09-11	1	37.00	0.05	37.00	35.15	t	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5322	76	28	2024-09-11	2	46.00	0.04	92.00	88.32	t	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5323	47	37	2024-09-11	6	88.00	0.01	528.00	522.72	t	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5324	76	38	2024-09-11	7	39.00	0.03	273.00	264.81	t	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5325	11	34	2024-09-11	5	9.50	0.06	47.50	44.65	t	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5326	64	40	2024-09-11	1	13.00	0.01	13.00	12.87	t	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5327	115	51	2024-09-11	6	31.50	0.06	189.00	177.66	t	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5328	98	41	2024-09-11	5	33.50	0.05	167.50	159.13	t	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5329	28	7	2024-09-11	1	90.00	0.09	90.00	81.90	t	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5330	16	26	2024-09-11	8	22.00	0.04	176.00	168.96	t	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5331	76	1	2024-09-12	3	30.00	0.10	90.00	81.00	t	3	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5332	36	18	2024-09-12	10	43.00	0.10	430.00	387.00	t	3	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5333	144	16	2024-09-12	1	26.00	0.09	26.00	23.66	t	3	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5334	52	2	2024-09-12	2	50.00	0.06	100.00	94.00	t	3	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5335	98	14	2024-09-12	7	12.00	0.01	84.00	83.16	t	3	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5336	64	12	2024-09-12	10	44.00	0.03	440.00	426.80	t	3	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5337	110	4	2024-09-12	4	10.00	0.05	40.00	38.00	t	3	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5338	46	50	2024-09-12	7	17.50	0.09	122.50	111.48	t	3	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5339	32	30	2024-09-12	8	18.00	0.07	144.00	133.92	t	3	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5340	58	5	2024-09-12	2	60.00	0.01	120.00	118.80	t	3	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5341	135	28	2024-09-12	10	46.00	0.01	460.00	455.40	t	3	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5342	131	12	2024-09-12	4	44.00	0.07	176.00	163.68	t	3	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5343	77	3	2024-09-12	8	20.00	0.09	160.00	145.60	t	3	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5344	10	21	2024-09-12	2	34.00	0.10	68.00	61.20	t	3	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5345	82	48	2024-09-12	3	44.50	0.07	133.50	124.15	t	3	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5346	79	4	2024-09-12	5	10.00	0.07	50.00	46.50	t	3	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5347	77	40	2024-09-12	9	13.00	0.03	117.00	113.49	t	3	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5348	2	17	2024-09-12	9	80.00	0.02	720.00	705.60	t	3	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5349	150	39	2024-09-12	6	35.00	0.08	210.00	193.20	t	3	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5350	77	40	2024-09-12	2	13.00	0.06	26.00	24.44	t	3	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5351	99	44	2024-09-12	8	10.50	0.10	84.00	75.60	t	3	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5352	19	43	2024-09-13	1	28.00	0.02	28.00	27.44	t	4	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5353	30	32	2024-09-13	9	48.00	0.03	432.00	419.04	t	4	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5354	72	44	2024-09-13	6	10.50	0.08	63.00	57.96	t	4	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5355	3	34	2024-09-13	9	9.50	0.09	85.50	77.81	t	4	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5356	136	29	2024-09-13	5	40.00	0.03	200.00	194.00	t	4	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5357	128	22	2024-09-13	4	54.00	0.02	216.00	211.68	t	4	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5358	129	14	2024-09-13	6	12.00	0.01	72.00	71.28	t	4	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5359	17	7	2024-09-13	4	90.00	0.08	360.00	331.20	t	4	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5360	39	14	2024-09-13	4	12.00	0.06	48.00	45.12	t	4	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5361	12	40	2024-09-13	4	13.00	0.05	52.00	49.40	t	4	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5362	82	4	2024-09-13	4	10.00	0.00	40.00	40.00	f	4	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5363	10	4	2024-09-13	5	10.00	0.06	50.00	47.00	t	4	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5364	20	48	2024-09-13	8	44.50	0.03	356.00	345.32	t	4	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5365	113	43	2024-09-13	1	28.00	0.05	28.00	26.60	t	4	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5366	138	34	2024-09-14	5	9.50	0.09	47.50	43.23	t	5	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5367	75	53	2024-09-14	10	22.50	0.07	225.00	209.25	t	5	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5368	141	12	2024-09-14	5	44.00	0.06	220.00	206.80	t	5	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5369	99	43	2024-09-14	2	28.00	0.02	56.00	54.88	t	5	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5370	114	43	2024-09-14	7	28.00	0.04	196.00	188.16	t	5	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5371	41	49	2024-09-14	2	39.50	0.04	79.00	75.84	t	5	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5372	42	34	2024-09-15	8	9.50	0.09	76.00	69.16	t	6	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5373	10	10	2024-09-15	6	15.00	0.08	90.00	82.80	t	6	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5374	79	5	2024-09-15	9	60.00	0.06	540.00	507.60	t	6	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5375	25	42	2024-09-15	8	53.00	0.06	424.00	398.56	t	6	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5376	144	44	2024-09-15	8	10.50	0.02	84.00	82.32	t	6	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5377	78	13	2024-09-15	4	23.00	0.09	92.00	83.72	t	6	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5378	142	51	2024-09-15	10	31.50	0.06	315.00	296.10	t	6	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5379	84	14	2024-09-15	4	12.00	0.10	48.00	43.20	t	6	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5380	34	6	2024-09-15	8	25.00	0.02	200.00	196.00	t	6	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5381	114	18	2024-09-15	3	43.00	0.07	129.00	119.97	t	6	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5382	68	48	2024-09-15	9	44.50	0.05	400.50	380.47	t	6	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5383	101	39	2024-09-15	3	35.00	0.05	105.00	99.75	t	6	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5384	132	25	2024-09-15	4	65.00	0.01	260.00	257.40	t	6	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5385	3	5	2024-09-15	10	60.00	0.03	600.00	582.00	t	6	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5386	87	39	2024-09-15	5	35.00	0.06	175.00	164.50	t	6	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5387	81	10	2024-09-15	2	15.00	0.00	30.00	30.00	f	6	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5388	149	35	2024-09-15	2	63.00	0.04	126.00	120.96	t	6	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5389	85	2	2024-09-15	2	50.00	0.06	100.00	94.00	t	6	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5390	17	43	2024-09-15	10	28.00	0.04	280.00	268.80	t	6	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5391	38	47	2024-09-15	9	82.50	0.02	742.50	727.65	t	6	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5392	119	20	2024-09-16	4	17.00	0.08	68.00	62.56	t	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5393	116	20	2024-09-16	10	17.00	0.09	170.00	154.70	t	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5394	62	36	2024-09-16	8	26.50	0.10	212.00	190.80	t	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5395	80	3	2024-09-16	6	20.00	0.01	120.00	118.80	t	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5396	57	26	2024-09-16	1	22.00	0.01	22.00	21.78	t	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5397	17	35	2024-09-16	10	63.00	0.03	630.00	611.10	t	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5398	110	30	2024-09-16	1	18.00	0.03	18.00	17.46	t	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5399	23	34	2024-09-16	9	9.50	0.09	85.50	77.81	t	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5400	104	34	2024-09-16	3	9.50	0.05	28.50	27.08	t	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5401	147	19	2024-09-16	8	38.00	0.00	304.00	304.00	f	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5402	83	33	2024-09-16	3	21.00	0.04	63.00	60.48	t	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5403	78	39	2024-09-16	4	35.00	0.00	140.00	140.00	f	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5404	103	43	2024-09-16	8	28.00	0.03	224.00	217.28	t	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5405	53	6	2024-09-16	10	25.00	0.06	250.00	235.00	t	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5406	110	15	2024-09-17	4	70.00	0.05	280.00	266.00	t	1	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5407	42	18	2024-09-17	1	43.00	0.03	43.00	41.71	t	1	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5408	111	38	2024-09-17	3	39.00	0.02	117.00	114.66	t	1	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5409	43	46	2024-09-17	8	25.50	0.04	204.00	195.84	t	1	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5410	37	7	2024-09-17	2	90.00	0.02	180.00	176.40	t	1	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5411	66	1	2024-09-17	10	30.00	0.09	300.00	273.00	t	1	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5412	87	34	2024-09-17	1	9.50	0.02	9.50	9.31	t	1	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5413	4	49	2024-09-17	8	39.50	0.09	316.00	287.56	t	1	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5414	136	16	2024-09-17	4	26.00	0.01	104.00	102.96	t	1	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5415	70	17	2024-09-17	4	80.00	0.10	320.00	288.00	t	1	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5416	71	36	2024-09-17	5	26.50	0.02	132.50	129.85	t	1	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5417	47	40	2024-09-17	8	13.00	0.04	104.00	99.84	t	1	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5418	51	43	2024-09-17	4	28.00	0.03	112.00	108.64	t	1	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5419	48	20	2024-09-17	9	17.00	0.06	153.00	143.82	t	1	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5420	113	12	2024-09-17	8	44.00	0.09	352.00	320.32	t	1	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5421	142	9	2024-09-17	10	36.00	0.07	360.00	334.80	t	1	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5422	59	53	2024-09-17	8	22.50	0.09	180.00	163.80	t	1	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5423	80	1	2024-09-17	3	30.00	0.05	90.00	85.50	t	1	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5424	10	46	2024-09-18	1	25.50	0.03	25.50	24.74	t	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5425	81	42	2024-09-18	10	53.00	0.06	530.00	498.20	t	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5426	27	33	2024-09-18	2	21.00	0.03	42.00	40.74	t	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5427	143	25	2024-09-18	7	65.00	0.08	455.00	418.60	t	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5428	18	48	2024-09-18	1	44.50	0.03	44.50	43.17	t	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5429	28	39	2024-09-18	2	35.00	0.04	70.00	67.20	t	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5430	131	50	2024-09-18	3	17.50	0.09	52.50	47.78	t	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5431	6	23	2024-09-18	5	24.00	0.09	120.00	109.20	t	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5432	13	31	2024-09-18	7	37.00	0.01	259.00	256.41	t	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5433	40	50	2024-09-18	7	17.50	0.09	122.50	111.48	t	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5434	41	43	2024-09-18	9	28.00	0.03	252.00	244.44	t	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5435	18	37	2024-09-18	10	88.00	0.09	880.00	800.80	t	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5436	15	51	2024-09-18	7	31.50	0.02	220.50	216.09	t	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5437	4	15	2024-09-19	7	70.00	0.09	490.00	445.90	t	3	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5438	119	14	2024-09-19	2	12.00	0.09	24.00	21.84	t	3	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5439	101	19	2024-09-19	3	38.00	0.09	114.00	103.74	t	3	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5440	27	18	2024-09-19	9	43.00	0.08	387.00	356.04	t	3	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5441	27	30	2024-09-19	10	18.00	0.09	180.00	163.80	t	3	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5442	94	6	2024-09-19	5	25.00	0.09	125.00	113.75	t	3	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5443	28	48	2024-09-19	8	44.50	0.07	356.00	331.08	t	3	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5444	2	11	2024-09-19	3	32.00	0.02	96.00	94.08	t	3	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5445	145	16	2024-09-19	10	26.00	0.07	260.00	241.80	t	3	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5446	70	20	2024-09-19	9	17.00	0.07	153.00	142.29	t	3	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5447	12	51	2024-09-19	3	31.50	0.02	94.50	92.61	t	3	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5448	13	45	2024-09-19	10	59.50	0.07	595.00	553.35	t	3	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5449	121	25	2024-09-19	6	65.00	0.08	390.00	358.80	t	3	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5450	80	30	2024-09-19	8	18.00	0.09	144.00	131.04	t	3	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5451	69	46	2024-09-19	6	25.50	0.01	153.00	151.47	t	3	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5452	36	29	2024-09-19	9	40.00	0.05	360.00	342.00	t	3	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5453	147	17	2024-09-19	3	80.00	0.03	240.00	232.80	t	3	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5454	56	37	2024-09-19	3	88.00	0.03	264.00	256.08	t	3	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5455	2	43	2024-09-20	8	28.00	0.04	224.00	215.04	t	4	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5456	66	20	2024-09-20	4	17.00	0.07	68.00	63.24	t	4	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5457	9	25	2024-09-20	4	65.00	0.08	260.00	239.20	t	4	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5458	118	40	2024-09-20	4	13.00	0.01	52.00	51.48	t	4	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5459	88	49	2024-09-20	5	39.50	0.03	197.50	191.58	t	4	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5460	10	46	2024-09-20	6	25.50	0.03	153.00	148.41	t	4	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5461	116	16	2024-09-20	1	26.00	0.04	26.00	24.96	t	4	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5462	77	24	2024-09-20	1	11.00	0.05	11.00	10.45	t	4	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5463	27	15	2024-09-20	10	70.00	0.09	700.00	637.00	t	4	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5464	1	37	2024-09-20	7	88.00	0.08	616.00	566.72	t	4	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5465	65	28	2024-09-20	3	46.00	0.01	138.00	136.62	t	4	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5466	88	35	2024-09-20	3	63.00	0.05	189.00	179.55	t	4	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5467	40	9	2024-09-20	7	36.00	0.04	252.00	241.92	t	4	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5468	133	24	2024-09-20	1	11.00	0.03	11.00	10.67	t	4	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5469	57	48	2024-09-20	5	44.50	0.07	222.50	206.92	t	4	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5470	54	42	2024-09-20	7	53.00	0.03	371.00	359.87	t	4	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5471	26	33	2024-09-20	2	21.00	0.01	42.00	41.58	t	4	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5472	106	45	2024-09-20	1	59.50	0.02	59.50	58.31	t	4	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5473	76	42	2024-09-20	6	53.00	0.01	318.00	314.82	t	4	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5474	120	31	2024-09-21	7	37.00	0.10	259.00	233.10	t	5	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5475	54	10	2024-09-21	8	15.00	0.04	120.00	115.20	t	5	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5476	21	48	2024-09-21	9	44.50	0.01	400.50	396.50	t	5	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5477	42	44	2024-09-21	1	10.50	0.01	10.50	10.40	t	5	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5478	97	38	2024-09-21	8	39.00	0.06	312.00	293.28	t	5	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5479	94	25	2024-09-21	7	65.00	0.06	455.00	427.70	t	5	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5480	148	34	2024-09-21	3	9.50	0.03	28.50	27.65	t	5	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5481	30	7	2024-09-21	1	90.00	0.06	90.00	84.60	t	5	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5482	113	47	2024-09-21	2	82.50	0.01	165.00	163.35	t	5	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5483	135	51	2024-09-21	6	31.50	0.05	189.00	179.55	t	5	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5484	139	19	2024-09-21	1	38.00	0.06	38.00	35.72	t	5	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5485	128	12	2024-09-21	3	44.00	0.08	132.00	121.44	t	5	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5486	17	41	2024-09-21	3	33.50	0.06	100.50	94.47	t	5	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5487	60	26	2024-09-21	5	22.00	0.08	110.00	101.20	t	5	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5488	50	38	2024-09-21	8	39.00	0.03	312.00	302.64	t	5	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5489	150	10	2024-09-22	1	15.00	0.03	15.00	14.55	t	6	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5490	143	32	2024-09-22	8	48.00	0.00	384.00	384.00	f	6	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5491	74	38	2024-09-22	6	39.00	0.07	234.00	217.62	t	6	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5492	82	1	2024-09-22	7	30.00	0.10	210.00	189.00	t	6	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5493	9	26	2024-09-22	1	22.00	0.08	22.00	20.24	t	6	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5494	141	36	2024-09-22	9	26.50	0.05	238.50	226.58	t	6	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5495	32	27	2024-09-22	5	85.00	0.07	425.00	395.25	t	6	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5496	12	13	2024-09-22	2	23.00	0.08	46.00	42.32	t	6	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5497	11	11	2024-09-22	3	32.00	0.03	96.00	93.12	t	6	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5498	105	28	2024-09-22	2	46.00	0.09	92.00	83.72	t	6	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5499	96	10	2024-09-22	2	15.00	0.05	30.00	28.50	t	6	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5500	84	35	2024-09-22	4	63.00	0.10	252.00	226.80	t	6	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5501	48	34	2024-09-22	2	9.50	0.03	19.00	18.43	t	6	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5502	23	21	2024-09-22	9	34.00	0.06	306.00	287.64	t	6	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5503	129	10	2024-09-23	9	15.00	0.06	135.00	126.90	t	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5504	56	25	2024-09-23	4	65.00	0.04	260.00	249.60	t	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5505	83	16	2024-09-23	1	26.00	0.06	26.00	24.44	t	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5506	131	33	2024-09-23	8	21.00	0.01	168.00	166.32	t	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5507	54	25	2024-09-23	1	65.00	0.04	65.00	62.40	t	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5508	71	43	2024-09-23	2	28.00	0.06	56.00	52.64	t	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5509	57	27	2024-09-23	1	85.00	0.02	85.00	83.30	t	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5510	119	43	2024-09-23	9	28.00	0.08	252.00	231.84	t	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5511	95	33	2024-09-23	4	21.00	0.08	84.00	77.28	t	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5512	32	21	2024-09-23	7	34.00	0.02	238.00	233.24	t	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5513	110	11	2024-09-23	6	32.00	0.03	192.00	186.24	t	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5514	66	53	2024-09-23	3	22.50	0.09	67.50	61.43	t	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5515	36	46	2024-09-23	7	25.50	0.05	178.50	169.58	t	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5516	17	33	2024-09-23	9	21.00	0.08	189.00	173.88	t	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5517	41	25	2024-09-23	4	65.00	0.09	260.00	236.60	t	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5518	142	19	2024-09-23	8	38.00	0.01	304.00	300.96	t	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5519	150	8	2024-09-24	4	40.00	0.07	160.00	148.80	t	1	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5520	131	26	2024-09-24	7	22.00	0.02	154.00	150.92	t	1	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5521	111	35	2024-09-24	6	63.00	0.08	378.00	347.76	t	1	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5522	118	18	2024-09-24	4	43.00	0.07	172.00	159.96	t	1	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5523	42	42	2024-09-24	7	53.00	0.04	371.00	356.16	t	1	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5524	60	43	2024-09-24	5	28.00	0.06	140.00	131.60	t	1	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5525	34	15	2024-09-24	10	70.00	0.09	700.00	637.00	t	1	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5526	7	43	2024-09-24	4	28.00	0.02	112.00	109.76	t	1	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5527	104	26	2024-09-24	4	22.00	0.04	88.00	84.48	t	1	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5528	42	8	2024-09-24	6	40.00	0.06	240.00	225.60	t	1	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5529	116	44	2024-09-24	6	10.50	0.06	63.00	59.22	t	1	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5530	10	45	2024-09-24	1	59.50	0.09	59.50	54.15	t	1	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5531	149	8	2024-09-24	4	40.00	0.02	160.00	156.80	t	1	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5532	31	49	2024-09-24	7	39.50	0.05	276.50	262.68	t	1	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5533	15	16	2024-09-24	2	26.00	0.09	52.00	47.32	t	1	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5534	34	29	2024-09-24	1	40.00	0.07	40.00	37.20	t	1	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5535	139	18	2024-09-24	3	43.00	0.09	129.00	117.39	t	1	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5536	97	34	2024-09-25	9	9.50	0.04	85.50	82.08	t	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5537	62	16	2024-09-25	2	26.00	0.08	52.00	47.84	t	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5538	46	4	2024-09-25	4	10.00	0.01	40.00	39.60	t	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5539	148	36	2024-09-25	4	26.50	0.10	106.00	95.40	t	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5540	137	27	2024-09-25	7	85.00	0.05	595.00	565.25	t	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5541	37	51	2024-09-25	10	31.50	0.08	315.00	289.80	t	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5542	44	42	2024-09-25	4	53.00	0.05	212.00	201.40	t	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5543	92	26	2024-09-25	2	22.00	0.00	44.00	44.00	f	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5544	71	35	2024-09-25	7	63.00	0.03	441.00	427.77	t	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5545	64	34	2024-09-25	2	9.50	0.06	19.00	17.86	t	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5546	118	47	2024-09-25	8	82.50	0.07	660.00	613.80	t	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5547	150	37	2024-09-25	6	88.00	0.08	528.00	485.76	t	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5548	10	5	2024-09-25	5	60.00	0.04	300.00	288.00	t	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5549	64	22	2024-09-25	9	54.00	0.01	486.00	481.14	t	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5550	92	6	2024-09-25	6	25.00	0.02	150.00	147.00	t	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5551	46	37	2024-09-25	1	88.00	0.09	88.00	80.08	t	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5552	88	45	2024-09-25	8	59.50	0.01	476.00	471.24	t	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5553	22	53	2024-09-25	10	22.50	0.04	225.00	216.00	t	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5554	138	53	2024-09-25	4	22.50	0.03	90.00	87.30	t	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5555	131	30	2024-09-25	2	18.00	0.08	36.00	33.12	t	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5556	138	10	2024-09-25	7	15.00	0.06	105.00	98.70	t	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5557	53	5	2024-09-25	8	60.00	0.09	480.00	436.80	t	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5558	61	34	2024-09-25	4	9.50	0.06	38.00	35.72	t	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5559	55	3	2024-09-25	5	20.00	0.04	100.00	96.00	t	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5560	89	5	2024-09-25	10	60.00	0.03	600.00	582.00	t	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5561	57	53	2024-09-25	3	22.50	0.01	67.50	66.83	t	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5562	91	15	2024-09-25	1	70.00	0.04	70.00	67.20	t	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5563	10	7	2024-09-25	5	90.00	0.06	450.00	423.00	t	2	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5564	136	51	2024-09-26	3	31.50	0.08	94.50	86.94	t	3	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5565	73	46	2024-09-26	8	25.50	0.10	204.00	183.60	t	3	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5566	48	19	2024-09-26	9	38.00	0.03	342.00	331.74	t	3	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5567	124	3	2024-09-26	9	20.00	0.02	180.00	176.40	t	3	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5568	46	13	2024-09-26	7	23.00	0.01	161.00	159.39	t	3	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5569	115	15	2024-09-26	2	70.00	0.08	140.00	128.80	t	3	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5570	98	11	2024-09-26	1	32.00	0.09	32.00	29.12	t	3	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5571	59	36	2024-09-26	10	26.50	0.04	265.00	254.40	t	3	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5572	97	3	2024-09-26	5	20.00	0.06	100.00	94.00	t	3	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5573	88	53	2024-09-26	10	22.50	0.02	225.00	220.50	t	3	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5574	42	41	2024-09-26	3	33.50	0.04	100.50	96.48	t	3	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5575	64	35	2024-09-26	8	63.00	0.09	504.00	458.64	t	3	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5576	92	23	2024-09-26	9	24.00	0.00	216.00	216.00	f	3	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5577	102	1	2024-09-26	6	30.00	0.03	180.00	174.60	t	3	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5578	131	36	2024-09-26	2	26.50	0.03	53.00	51.41	t	3	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5579	87	42	2024-09-27	9	53.00	0.03	477.00	462.69	t	4	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5580	110	34	2024-09-27	4	9.50	0.08	38.00	34.96	t	4	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5581	137	25	2024-09-27	4	65.00	0.06	260.00	244.40	t	4	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5582	110	36	2024-09-27	10	26.50	0.02	265.00	259.70	t	4	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5583	60	28	2024-09-27	2	46.00	0.01	92.00	91.08	t	4	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5584	22	11	2024-09-27	6	32.00	0.06	192.00	180.48	t	4	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5585	59	36	2024-09-27	8	26.50	0.04	212.00	203.52	t	4	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5586	127	12	2024-09-27	1	44.00	0.09	44.00	40.04	t	4	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5587	14	48	2024-09-27	4	44.50	0.05	178.00	169.10	t	4	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5588	45	10	2024-09-27	4	15.00	0.02	60.00	58.80	t	4	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5589	87	21	2024-09-27	8	34.00	0.07	272.00	252.96	t	4	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5590	66	10	2024-09-27	5	15.00	0.03	75.00	72.75	t	4	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5591	118	33	2024-09-27	5	21.00	0.08	105.00	96.60	t	4	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5592	126	16	2024-09-27	5	26.00	0.05	130.00	123.50	t	4	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5593	27	29	2024-09-27	2	40.00	0.04	80.00	76.80	t	4	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5594	42	49	2024-09-27	9	39.50	0.01	355.50	351.95	t	4	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5595	133	50	2024-09-27	4	17.50	0.06	70.00	65.80	t	4	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5596	32	36	2024-09-27	2	26.50	0.05	53.00	50.35	t	4	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5597	87	23	2024-09-27	8	24.00	0.05	192.00	182.40	t	4	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5598	80	50	2024-09-28	8	17.50	0.07	140.00	130.20	t	5	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5599	147	30	2024-09-28	8	18.00	0.01	144.00	142.56	t	5	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5600	113	29	2024-09-28	7	40.00	0.06	280.00	263.20	t	5	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5601	126	6	2024-09-28	7	25.00	0.04	175.00	168.00	t	5	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5602	26	8	2024-09-28	6	40.00	0.03	240.00	232.80	t	5	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5603	26	48	2024-09-28	4	44.50	0.07	178.00	165.54	t	5	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5604	3	34	2024-09-28	4	9.50	0.08	38.00	34.96	t	5	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5605	113	52	2024-09-28	10	47.50	0.01	475.00	470.25	t	5	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5606	44	53	2024-09-28	5	22.50	0.06	112.50	105.75	t	5	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5607	93	5	2024-09-28	9	60.00	0.01	540.00	534.60	t	5	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5608	138	51	2024-09-28	5	31.50	0.03	157.50	152.78	t	5	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5609	144	3	2024-09-28	6	20.00	0.01	120.00	118.80	t	5	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5610	18	26	2024-09-28	1	22.00	0.02	22.00	21.56	t	5	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5611	115	50	2024-09-28	2	17.50	0.00	35.00	35.00	f	5	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5612	48	46	2024-09-28	10	25.50	0.07	255.00	237.15	t	5	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5613	150	52	2024-09-28	10	47.50	0.09	475.00	432.25	t	5	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5614	53	47	2024-09-28	6	82.50	0.00	495.00	495.00	f	5	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5615	101	18	2024-09-28	5	43.00	0.05	215.00	204.25	t	5	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5616	135	48	2024-09-28	5	44.50	0.05	222.50	211.38	t	5	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5617	145	19	2024-09-28	3	38.00	0.08	114.00	104.88	t	5	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5618	123	35	2024-09-28	3	63.00	0.06	189.00	177.66	t	5	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5619	95	17	2024-09-28	7	80.00	0.03	560.00	543.20	t	5	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5620	15	52	2024-09-29	7	47.50	0.05	332.50	315.88	t	6	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5621	80	24	2024-09-29	8	11.00	0.09	88.00	80.08	t	6	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5622	52	2	2024-09-29	7	50.00	0.05	350.00	332.50	t	6	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5623	45	37	2024-09-29	3	88.00	0.09	264.00	240.24	t	6	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5624	41	2	2024-09-29	6	50.00	0.05	300.00	285.00	t	6	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5625	32	41	2024-09-29	9	33.50	0.03	301.50	292.46	t	6	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5626	115	40	2024-09-29	7	13.00	0.08	91.00	83.72	t	6	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5627	122	9	2024-09-29	9	36.00	0.06	324.00	304.56	t	6	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5628	112	52	2024-09-29	2	47.50	0.02	95.00	93.10	t	6	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5629	139	23	2024-09-29	8	24.00	0.06	192.00	180.48	t	6	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5630	42	6	2024-09-29	4	25.00	0.01	100.00	99.00	t	6	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5631	138	21	2024-09-29	6	34.00	0.02	204.00	199.92	t	6	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5632	105	35	2024-09-29	4	63.00	0.05	252.00	239.40	t	6	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5633	68	19	2024-09-29	7	38.00	0.09	266.00	242.06	t	6	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5634	95	12	2024-09-29	8	44.00	0.08	352.00	323.84	t	6	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5635	117	15	2024-09-29	7	70.00	0.07	490.00	455.70	t	6	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5636	79	5	2024-09-29	5	60.00	0.09	300.00	273.00	t	6	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5637	103	30	2024-09-30	4	18.00	0.03	72.00	69.84	t	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5638	36	29	2024-09-30	5	40.00	0.01	200.00	198.00	t	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5639	58	42	2024-09-30	4	53.00	0.06	212.00	199.28	t	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5640	126	6	2024-09-30	1	25.00	0.00	25.00	25.00	f	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5641	106	42	2024-09-30	4	53.00	0.03	212.00	205.64	t	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5642	54	35	2024-09-30	6	63.00	0.09	378.00	343.98	t	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5643	23	53	2024-09-30	5	22.50	0.09	112.50	102.38	t	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5644	146	29	2024-09-30	3	40.00	0.09	120.00	109.20	t	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5645	31	37	2024-09-30	8	88.00	0.00	704.00	704.00	f	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5646	19	28	2024-09-30	8	46.00	0.05	368.00	349.60	t	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5647	88	32	2024-09-30	10	48.00	0.02	480.00	470.40	t	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5648	48	50	2024-09-30	9	17.50	0.00	157.50	157.50	f	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5649	124	52	2024-09-30	4	47.50	0.05	190.00	180.50	t	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5650	30	48	2024-09-30	1	44.50	0.03	44.50	43.17	t	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5651	108	13	2024-09-30	10	23.00	0.08	230.00	211.60	t	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5652	111	48	2024-09-30	10	44.50	0.08	445.00	409.40	t	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5653	103	28	2024-09-30	6	46.00	0.04	276.00	264.96	t	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5654	73	10	2024-09-30	1	15.00	0.05	15.00	14.25	t	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5655	36	52	2024-09-30	6	47.50	0.05	285.00	270.75	t	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5656	111	25	2024-09-30	10	65.00	0.02	650.00	637.00	t	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5657	60	20	2024-09-30	1	17.00	0.03	17.00	16.49	t	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5658	119	14	2024-09-30	2	12.00	0.06	24.00	22.56	t	0	9	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5659	64	42	2024-10-01	5	53.00	0.01	265.00	262.35	t	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5660	10	46	2024-10-01	5	25.50	0.06	127.50	119.85	t	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5661	54	5	2024-10-01	9	60.00	0.01	540.00	534.60	t	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5662	68	25	2024-10-01	10	65.00	0.08	650.00	598.00	t	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5663	83	14	2024-10-01	1	12.00	0.03	12.00	11.64	t	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5664	20	9	2024-10-01	4	36.00	0.07	144.00	133.92	t	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5665	16	45	2024-10-01	9	59.50	0.04	535.50	514.08	t	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5666	132	33	2024-10-01	4	21.00	0.01	84.00	83.16	t	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5667	78	13	2024-10-01	1	23.00	0.06	23.00	21.62	t	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5668	138	20	2024-10-01	2	17.00	0.08	34.00	31.28	t	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5669	68	35	2024-10-01	4	63.00	0.03	252.00	244.44	t	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5670	85	30	2024-10-01	3	18.00	0.04	54.00	51.84	t	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5671	27	38	2024-10-01	9	39.00	0.09	351.00	319.41	t	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5672	85	15	2024-10-01	10	70.00	0.08	700.00	644.00	t	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5673	63	29	2024-10-01	3	40.00	0.08	120.00	110.40	t	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5674	10	26	2024-10-01	3	22.00	0.03	66.00	64.02	t	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5675	46	45	2024-10-01	8	59.50	0.05	476.00	452.20	t	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5676	57	32	2024-10-01	7	48.00	0.03	336.00	325.92	t	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5677	67	51	2024-10-01	9	31.50	0.09	283.50	257.99	t	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5678	76	39	2024-10-01	3	35.00	0.08	105.00	96.60	t	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5679	13	36	2024-10-01	10	26.50	0.00	265.00	265.00	f	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5680	61	27	2024-10-01	2	85.00	0.00	170.00	170.00	f	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5681	127	6	2024-10-02	1	25.00	0.03	25.00	24.25	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5682	87	21	2024-10-02	8	34.00	0.09	272.00	247.52	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5683	27	32	2024-10-02	2	48.00	0.05	96.00	91.20	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5684	87	10	2024-10-02	3	15.00	0.05	45.00	42.75	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5685	88	23	2024-10-02	5	24.00	0.04	120.00	115.20	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5686	121	31	2024-10-02	2	37.00	0.09	74.00	67.34	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5687	146	28	2024-10-02	6	46.00	0.04	276.00	264.96	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5688	137	14	2024-10-02	9	12.00	0.00	108.00	108.00	f	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5689	24	13	2024-10-02	8	23.00	0.09	184.00	167.44	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5690	77	38	2024-10-02	10	39.00	0.01	390.00	386.10	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5691	18	30	2024-10-02	9	18.00	0.03	162.00	157.14	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5692	30	39	2024-10-02	6	35.00	0.06	210.00	197.40	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5693	55	13	2024-10-02	5	23.00	0.10	115.00	103.50	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5694	77	8	2024-10-03	7	40.00	0.07	280.00	260.40	t	3	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5695	18	28	2024-10-03	3	46.00	0.06	138.00	129.72	t	3	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5696	9	11	2024-10-03	1	32.00	0.03	32.00	31.04	t	3	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5697	112	20	2024-10-03	8	17.00	0.02	136.00	133.28	t	3	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5698	35	28	2024-10-03	9	46.00	0.07	414.00	385.02	t	3	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5699	104	43	2024-10-03	4	28.00	0.04	112.00	107.52	t	3	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5700	15	4	2024-10-03	2	10.00	0.00	20.00	20.00	f	3	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5701	24	36	2024-10-03	3	26.50	0.04	79.50	76.32	t	3	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5702	64	45	2024-10-03	3	59.50	0.09	178.50	162.44	t	3	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5703	108	31	2024-10-04	7	37.00	0.03	259.00	251.23	t	4	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5704	71	49	2024-10-04	9	39.50	0.02	355.50	348.39	t	4	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5705	46	41	2024-10-04	7	33.50	0.03	234.50	227.47	t	4	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5706	68	39	2024-10-04	4	35.00	0.05	140.00	133.00	t	4	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5707	1	39	2024-10-04	6	35.00	0.02	210.00	205.80	t	4	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5708	16	30	2024-10-04	9	18.00	0.09	162.00	147.42	t	4	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5709	5	40	2024-10-04	4	13.00	0.08	52.00	47.84	t	4	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5710	123	11	2024-10-04	9	32.00	0.03	288.00	279.36	t	4	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5711	53	43	2024-10-04	5	28.00	0.03	140.00	135.80	t	4	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5712	114	41	2024-10-04	5	33.50	0.01	167.50	165.83	t	4	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5713	48	43	2024-10-04	4	28.00	0.05	112.00	106.40	t	4	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5714	86	6	2024-10-04	4	25.00	0.01	100.00	99.00	t	4	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5715	15	24	2024-10-04	1	11.00	0.04	11.00	10.56	t	4	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5716	56	1	2024-10-04	3	30.00	0.03	90.00	87.30	t	4	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5717	35	38	2024-10-05	3	39.00	0.04	117.00	112.32	t	5	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5718	65	18	2024-10-05	7	43.00	0.01	301.00	297.99	t	5	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5719	74	46	2024-10-05	2	25.50	0.06	51.00	47.94	t	5	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5720	148	35	2024-10-05	7	63.00	0.01	441.00	436.59	t	5	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5721	3	26	2024-10-05	6	22.00	0.01	132.00	130.68	t	5	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5722	57	38	2024-10-05	9	39.00	0.01	351.00	347.49	t	5	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5723	50	35	2024-10-05	7	63.00	0.06	441.00	414.54	t	5	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5724	82	22	2024-10-05	3	54.00	0.07	162.00	150.66	t	5	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5725	59	34	2024-10-05	1	9.50	0.04	9.50	9.12	t	5	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5726	92	9	2024-10-05	8	36.00	0.10	288.00	259.20	t	5	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5727	65	9	2024-10-05	3	36.00	0.08	108.00	99.36	t	5	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5728	2	31	2024-10-05	9	37.00	0.06	333.00	313.02	t	5	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5729	74	39	2024-10-06	7	35.00	0.08	245.00	225.40	t	6	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5730	92	18	2024-10-06	8	43.00	0.09	344.00	313.04	t	6	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5731	57	36	2024-10-06	4	26.50	0.04	106.00	101.76	t	6	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5732	45	24	2024-10-06	10	11.00	0.01	110.00	108.90	t	6	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5733	142	47	2024-10-06	8	82.50	0.00	660.00	660.00	f	6	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5734	122	46	2024-10-06	1	25.50	0.08	25.50	23.46	t	6	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5735	123	44	2024-10-06	4	10.50	0.04	42.00	40.32	t	6	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5736	118	14	2024-10-06	5	12.00	0.03	60.00	58.20	t	6	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5737	37	47	2024-10-06	7	82.50	0.10	577.50	519.75	t	6	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5738	134	2	2024-10-06	8	50.00	0.07	400.00	372.00	t	6	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5739	107	16	2024-10-07	9	26.00	0.03	234.00	226.98	t	0	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5740	150	41	2024-10-07	3	33.50	0.04	100.50	96.48	t	0	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5741	76	14	2024-10-07	6	12.00	0.03	72.00	69.84	t	0	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5742	70	52	2024-10-07	9	47.50	0.09	427.50	389.03	t	0	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5743	92	13	2024-10-07	3	23.00	0.08	69.00	63.48	t	0	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5744	67	24	2024-10-07	5	11.00	0.10	55.00	49.50	t	0	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5745	149	50	2024-10-07	6	17.50	0.03	105.00	101.85	t	0	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5746	67	40	2024-10-07	10	13.00	0.01	130.00	128.70	t	0	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5747	99	37	2024-10-07	3	88.00	0.04	264.00	253.44	t	0	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5748	61	11	2024-10-07	5	32.00	0.09	160.00	145.60	t	0	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5749	70	20	2024-10-07	7	17.00	0.05	119.00	113.05	t	0	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5750	87	48	2024-10-07	5	44.50	0.02	222.50	218.05	t	0	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5751	119	39	2024-10-07	5	35.00	0.08	175.00	161.00	t	0	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5752	65	20	2024-10-07	7	17.00	0.02	119.00	116.62	t	0	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5753	62	47	2024-10-07	9	82.50	0.06	742.50	697.95	t	0	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5754	147	3	2024-10-07	1	20.00	0.03	20.00	19.40	t	0	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5755	130	48	2024-10-07	4	44.50	0.04	178.00	170.88	t	0	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5756	115	53	2024-10-07	9	22.50	0.10	202.50	182.25	t	0	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5757	55	33	2024-10-07	9	21.00	0.09	189.00	171.99	t	0	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5758	32	49	2024-10-07	10	39.50	0.09	395.00	359.45	t	0	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5759	116	15	2024-10-07	9	70.00	0.05	630.00	598.50	t	0	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5760	34	49	2024-10-08	10	39.50	0.04	395.00	379.20	t	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5761	110	19	2024-10-08	1	38.00	0.05	38.00	36.10	t	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5762	22	52	2024-10-08	8	47.50	0.10	380.00	342.00	t	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5763	95	29	2024-10-08	3	40.00	0.04	120.00	115.20	t	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5764	78	2	2024-10-08	5	50.00	0.09	250.00	227.50	t	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5765	64	18	2024-10-08	3	43.00	0.06	129.00	121.26	t	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5766	54	4	2024-10-08	9	10.00	0.07	90.00	83.70	t	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5767	148	45	2024-10-08	6	59.50	0.09	357.00	324.87	t	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5768	114	11	2024-10-08	8	32.00	0.07	256.00	238.08	t	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5769	48	28	2024-10-08	1	46.00	0.07	46.00	42.78	t	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5770	22	39	2024-10-08	7	35.00	0.09	245.00	222.95	t	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5771	73	22	2024-10-08	4	54.00	0.09	216.00	196.56	t	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5772	48	2	2024-10-08	7	50.00	0.09	350.00	318.50	t	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5773	32	53	2024-10-08	10	22.50	0.05	225.00	213.75	t	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5774	5	9	2024-10-08	1	36.00	0.08	36.00	33.12	t	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5775	74	7	2024-10-08	1	90.00	0.07	90.00	83.70	t	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5776	75	14	2024-10-08	10	12.00	0.01	120.00	118.80	t	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5777	32	24	2024-10-08	2	11.00	0.05	22.00	20.90	t	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5778	88	21	2024-10-08	4	34.00	0.06	136.00	127.84	t	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5779	147	46	2024-10-08	6	25.50	0.01	153.00	151.47	t	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5780	107	52	2024-10-08	5	47.50	0.08	237.50	218.50	t	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5781	41	31	2024-10-08	3	37.00	0.07	111.00	103.23	t	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5782	108	5	2024-10-08	8	60.00	0.01	480.00	475.20	t	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5783	143	9	2024-10-08	4	36.00	0.03	144.00	139.68	t	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5784	102	42	2024-10-08	9	53.00	0.04	477.00	457.92	t	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5785	4	41	2024-10-09	9	33.50	0.04	301.50	289.44	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5786	39	12	2024-10-09	9	44.00	0.04	396.00	380.16	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5787	83	35	2024-10-09	2	63.00	0.07	126.00	117.18	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5788	124	45	2024-10-09	2	59.50	0.09	119.00	108.29	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5789	110	11	2024-10-09	10	32.00	0.08	320.00	294.40	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5790	27	14	2024-10-09	3	12.00	0.04	36.00	34.56	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5791	129	8	2024-10-09	1	40.00	0.09	40.00	36.40	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5792	77	7	2024-10-09	9	90.00	0.09	810.00	737.10	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5793	141	22	2024-10-09	2	54.00	0.06	108.00	101.52	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5794	108	15	2024-10-09	9	70.00	0.03	630.00	611.10	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5795	79	30	2024-10-09	4	18.00	0.09	72.00	65.52	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5796	36	14	2024-10-09	6	12.00	0.08	72.00	66.24	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5797	14	41	2024-10-09	1	33.50	0.09	33.50	30.49	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5798	46	50	2024-10-09	6	17.50	0.04	105.00	100.80	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5799	97	53	2024-10-09	8	22.50	0.04	180.00	172.80	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5800	49	50	2024-10-09	10	17.50	0.08	175.00	161.00	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5801	73	1	2024-10-09	8	30.00	0.05	240.00	228.00	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5802	17	40	2024-10-10	6	13.00	0.06	78.00	73.32	t	3	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5803	121	39	2024-10-10	4	35.00	0.08	140.00	128.80	t	3	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5804	71	6	2024-10-10	8	25.00	0.06	200.00	188.00	t	3	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5805	50	35	2024-10-10	2	63.00	0.00	126.00	126.00	f	3	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5806	114	9	2024-10-10	5	36.00	0.00	180.00	180.00	f	3	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5807	52	47	2024-10-10	10	82.50	0.02	825.00	808.50	t	3	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5808	123	21	2024-10-10	10	34.00	0.08	340.00	312.80	t	3	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5809	128	46	2024-10-10	3	25.50	0.01	76.50	75.74	t	3	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5810	32	20	2024-10-10	9	17.00	0.02	153.00	149.94	t	3	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5811	18	14	2024-10-10	5	12.00	0.01	60.00	59.40	t	3	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5812	4	52	2024-10-10	9	47.50	0.00	427.50	427.50	f	3	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5813	128	46	2024-10-10	8	25.50	0.05	204.00	193.80	t	3	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5814	42	44	2024-10-10	5	10.50	0.02	52.50	51.45	t	3	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5815	10	22	2024-10-10	5	54.00	0.02	270.00	264.60	t	3	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5816	119	20	2024-10-10	8	17.00	0.06	136.00	127.84	t	3	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5817	49	3	2024-10-10	8	20.00	0.07	160.00	148.80	t	3	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5818	16	32	2024-10-11	7	48.00	0.01	336.00	332.64	t	4	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5819	39	21	2024-10-11	2	34.00	0.01	68.00	67.32	t	4	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5820	26	10	2024-10-11	9	15.00	0.08	135.00	124.20	t	4	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5821	103	22	2024-10-11	7	54.00	0.05	378.00	359.10	t	4	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5822	147	51	2024-10-11	3	31.50	0.04	94.50	90.72	t	4	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5823	9	9	2024-10-11	8	36.00	0.03	288.00	279.36	t	4	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5824	39	31	2024-10-11	6	37.00	0.07	222.00	206.46	t	4	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5825	58	20	2024-10-11	1	17.00	0.03	17.00	16.49	t	4	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5826	59	22	2024-10-11	4	54.00	0.07	216.00	200.88	t	4	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5827	59	24	2024-10-11	7	11.00	0.08	77.00	70.84	t	4	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5828	83	53	2024-10-11	2	22.50	0.08	45.00	41.40	t	4	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5829	3	28	2024-10-11	10	46.00	0.08	460.00	423.20	t	4	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5830	116	3	2024-10-11	2	20.00	0.09	40.00	36.40	t	4	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5831	23	19	2024-10-11	10	38.00	0.03	380.00	368.60	t	4	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5832	61	49	2024-10-11	8	39.50	0.01	316.00	312.84	t	4	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5833	75	42	2024-10-11	2	53.00	0.03	106.00	102.82	t	4	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5834	117	44	2024-10-11	4	10.50	0.06	42.00	39.48	t	4	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5835	109	50	2024-10-11	8	17.50	0.04	140.00	134.40	t	4	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5836	111	43	2024-10-11	3	28.00	0.09	84.00	76.44	t	4	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5837	64	45	2024-10-11	9	59.50	0.01	535.50	530.15	t	4	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5838	110	5	2024-10-12	1	60.00	0.09	60.00	54.60	t	5	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5839	120	26	2024-10-12	4	22.00	0.05	88.00	83.60	t	5	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5840	34	34	2024-10-12	7	9.50	0.09	66.50	60.52	t	5	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5841	109	38	2024-10-12	3	39.00	0.02	117.00	114.66	t	5	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5842	93	31	2024-10-12	3	37.00	0.01	111.00	109.89	t	5	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5843	136	23	2024-10-12	9	24.00	0.10	216.00	194.40	t	5	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5844	141	23	2024-10-12	9	24.00	0.09	216.00	196.56	t	5	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5845	101	9	2024-10-12	9	36.00	0.06	324.00	304.56	t	5	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5846	9	36	2024-10-12	8	26.50	0.04	212.00	203.52	t	5	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5847	25	43	2024-10-12	3	28.00	0.05	84.00	79.80	t	5	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5848	32	9	2024-10-12	1	36.00	0.05	36.00	34.20	t	5	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5849	129	30	2024-10-12	2	18.00	0.08	36.00	33.12	t	5	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5850	91	18	2024-10-12	10	43.00	0.03	430.00	417.10	t	5	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5851	57	17	2024-10-12	7	80.00	0.05	560.00	532.00	t	5	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5852	111	19	2024-10-12	4	38.00	0.04	152.00	145.92	t	5	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5853	61	6	2024-10-12	3	25.00	0.04	75.00	72.00	t	5	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5854	6	26	2024-10-13	7	22.00	0.10	154.00	138.60	t	6	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5855	90	25	2024-10-13	2	65.00	0.06	130.00	122.20	t	6	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5856	30	31	2024-10-13	1	37.00	0.08	37.00	34.04	t	6	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5857	95	24	2024-10-13	8	11.00	0.05	88.00	83.60	t	6	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5858	21	40	2024-10-13	8	13.00	0.04	104.00	99.84	t	6	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5859	120	41	2024-10-13	2	33.50	0.04	67.00	64.32	t	6	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5860	127	15	2024-10-13	3	70.00	0.04	210.00	201.60	t	6	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5861	78	51	2024-10-13	2	31.50	0.06	63.00	59.22	t	6	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5862	130	28	2024-10-13	4	46.00	0.09	184.00	167.44	t	6	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5863	81	44	2024-10-13	8	10.50	0.04	84.00	80.64	t	6	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5864	49	39	2024-10-13	3	35.00	0.03	105.00	101.85	t	6	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5865	133	8	2024-10-13	9	40.00	0.02	360.00	352.80	t	6	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5866	51	7	2024-10-13	7	90.00	0.02	630.00	617.40	t	6	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5867	116	53	2024-10-13	7	22.50	0.02	157.50	154.35	t	6	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5868	63	20	2024-10-13	8	17.00	0.01	136.00	134.64	t	6	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5869	140	33	2024-10-13	10	21.00	0.02	210.00	205.80	t	6	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5870	96	32	2024-10-13	2	48.00	0.09	96.00	87.36	t	6	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5871	25	23	2024-10-13	8	24.00	0.05	192.00	182.40	t	6	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5872	138	38	2024-10-13	9	39.00	0.06	351.00	329.94	t	6	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5873	50	4	2024-10-13	2	10.00	0.08	20.00	18.40	t	6	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5874	140	52	2024-10-13	7	47.50	0.00	332.50	332.50	f	6	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5875	4	37	2024-10-14	4	88.00	0.03	352.00	341.44	t	0	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5876	108	1	2024-10-14	4	30.00	0.02	120.00	117.60	t	0	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5877	87	20	2024-10-14	9	17.00	0.07	153.00	142.29	t	0	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5878	73	46	2024-10-14	5	25.50	0.03	127.50	123.68	t	0	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5879	20	23	2024-10-14	4	24.00	0.01	96.00	95.04	t	0	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5880	56	36	2024-10-14	9	26.50	0.02	238.50	233.73	t	0	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5881	120	47	2024-10-14	2	82.50	0.03	165.00	160.05	t	0	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5882	65	28	2024-10-14	1	46.00	0.07	46.00	42.78	t	0	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5883	53	9	2024-10-14	7	36.00	0.00	252.00	252.00	f	0	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5884	118	9	2024-10-14	10	36.00	0.01	360.00	356.40	t	0	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5885	145	11	2024-10-14	6	32.00	0.09	192.00	174.72	t	0	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5886	49	49	2024-10-14	4	39.50	0.05	158.00	150.10	t	0	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5887	2	49	2024-10-14	2	39.50	0.06	79.00	74.26	t	0	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5888	122	42	2024-10-15	7	53.00	0.05	371.00	352.45	t	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5889	40	40	2024-10-15	9	13.00	0.06	117.00	109.98	t	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5890	113	51	2024-10-15	5	31.50	0.08	157.50	144.90	t	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5891	102	50	2024-10-15	1	17.50	0.07	17.50	16.28	t	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5892	63	39	2024-10-15	3	35.00	0.02	105.00	102.90	t	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5893	3	11	2024-10-15	1	32.00	0.03	32.00	31.04	t	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5894	74	48	2024-10-15	5	44.50	0.02	222.50	218.05	t	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5895	76	45	2024-10-15	10	59.50	0.09	595.00	541.45	t	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5896	145	43	2024-10-15	6	28.00	0.06	168.00	157.92	t	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5897	80	40	2024-10-15	2	13.00	0.08	26.00	23.92	t	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5898	137	2	2024-10-15	6	50.00	0.07	300.00	279.00	t	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5899	29	50	2024-10-16	9	17.50	0.05	157.50	149.63	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5900	103	27	2024-10-16	2	85.00	0.03	170.00	164.90	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5901	124	10	2024-10-16	5	15.00	0.06	75.00	70.50	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5902	86	36	2024-10-16	1	26.50	0.10	26.50	23.85	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5903	62	22	2024-10-16	4	54.00	0.05	216.00	205.20	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5904	115	29	2024-10-16	8	40.00	0.04	320.00	307.20	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5905	146	20	2024-10-16	5	17.00	0.04	85.00	81.60	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5906	101	15	2024-10-16	7	70.00	0.05	490.00	465.50	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5907	87	15	2024-10-16	9	70.00	0.05	630.00	598.50	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5908	121	37	2024-10-16	5	88.00	0.05	440.00	418.00	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5909	101	20	2024-10-16	1	17.00	0.02	17.00	16.66	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5910	146	47	2024-10-16	1	82.50	0.07	82.50	76.73	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5911	110	15	2024-10-16	8	70.00	0.07	560.00	520.80	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5912	142	51	2024-10-16	6	31.50	0.01	189.00	187.11	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5913	19	18	2024-10-16	2	43.00	0.03	86.00	83.42	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5914	58	38	2024-10-16	1	39.00	0.07	39.00	36.27	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5915	68	32	2024-10-16	8	48.00	0.04	384.00	368.64	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5916	24	12	2024-10-16	3	44.00	0.07	132.00	122.76	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5917	144	34	2024-10-16	1	9.50	0.06	9.50	8.93	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5918	13	28	2024-10-16	8	46.00	0.09	368.00	334.88	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5919	133	53	2024-10-16	1	22.50	0.04	22.50	21.60	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5920	39	39	2024-10-16	3	35.00	0.03	105.00	101.85	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5921	121	48	2024-10-16	3	44.50	0.10	133.50	120.15	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5922	25	11	2024-10-16	7	32.00	0.08	224.00	206.08	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5923	129	14	2024-10-16	2	12.00	0.06	24.00	22.56	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5924	130	37	2024-10-16	2	88.00	0.02	176.00	172.48	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5925	70	32	2024-10-16	3	48.00	0.03	144.00	139.68	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5926	139	32	2024-10-16	6	48.00	0.06	288.00	270.72	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5927	135	30	2024-10-17	5	18.00	0.00	90.00	90.00	f	3	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5928	145	21	2024-10-17	4	34.00	0.03	136.00	131.92	t	3	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5929	111	27	2024-10-17	3	85.00	0.08	255.00	234.60	t	3	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5930	23	1	2024-10-17	10	30.00	0.05	300.00	285.00	t	3	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5931	58	44	2024-10-17	1	10.50	0.00	10.50	10.50	f	3	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5932	4	37	2024-10-17	2	88.00	0.09	176.00	160.16	t	3	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5933	66	43	2024-10-17	5	28.00	0.06	140.00	131.60	t	3	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5934	62	2	2024-10-17	1	50.00	0.03	50.00	48.50	t	3	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5935	7	53	2024-10-17	10	22.50	0.01	225.00	222.75	t	3	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5936	44	17	2024-10-17	7	80.00	0.09	560.00	509.60	t	3	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5937	17	18	2024-10-17	5	43.00	0.02	215.00	210.70	t	3	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5938	50	13	2024-10-17	2	23.00	0.05	46.00	43.70	t	3	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5939	113	47	2024-10-17	9	82.50	0.07	742.50	690.53	t	3	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5940	19	11	2024-10-18	5	32.00	0.03	160.00	155.20	t	4	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5941	105	46	2024-10-18	3	25.50	0.02	76.50	74.97	t	4	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5942	126	3	2024-10-18	5	20.00	0.02	100.00	98.00	t	4	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5943	126	5	2024-10-18	6	60.00	0.04	360.00	345.60	t	4	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5944	6	23	2024-10-18	4	24.00	0.09	96.00	87.36	t	4	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5945	67	26	2024-10-18	2	22.00	0.05	44.00	41.80	t	4	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5946	150	42	2024-10-18	9	53.00	0.09	477.00	434.07	t	4	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5947	9	5	2024-10-18	8	60.00	0.09	480.00	436.80	t	4	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5948	10	49	2024-10-18	1	39.50	0.07	39.50	36.74	t	4	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5949	117	36	2024-10-18	9	26.50	0.02	238.50	233.73	t	4	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5950	14	34	2024-10-18	5	9.50	0.07	47.50	44.18	t	4	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5951	22	38	2024-10-18	10	39.00	0.02	390.00	382.20	t	4	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5952	98	24	2024-10-18	3	11.00	0.02	33.00	32.34	t	4	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5953	147	43	2024-10-18	5	28.00	0.03	140.00	135.80	t	4	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5954	47	44	2024-10-18	9	10.50	0.09	94.50	86.00	t	4	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5955	143	20	2024-10-18	1	17.00	0.04	17.00	16.32	t	4	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5956	35	36	2024-10-18	6	26.50	0.02	159.00	155.82	t	4	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5957	1	24	2024-10-19	5	11.00	0.02	55.00	53.90	t	5	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5958	12	45	2024-10-19	7	59.50	0.05	416.50	395.67	t	5	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5959	123	28	2024-10-19	8	46.00	0.01	368.00	364.32	t	5	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5960	6	47	2024-10-19	2	82.50	0.05	165.00	156.75	t	5	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5961	26	33	2024-10-19	7	21.00	0.01	147.00	145.53	t	5	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5962	11	39	2024-10-19	7	35.00	0.05	245.00	232.75	t	5	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5963	132	24	2024-10-19	9	11.00	0.08	99.00	91.08	t	5	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5964	57	46	2024-10-19	5	25.50	0.00	127.50	127.50	f	5	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5965	100	10	2024-10-19	5	15.00	0.06	75.00	70.50	t	5	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5966	67	15	2024-10-19	4	70.00	0.03	280.00	271.60	t	5	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5967	79	23	2024-10-19	3	24.00	0.02	72.00	70.56	t	5	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5968	27	29	2024-10-19	1	40.00	0.00	40.00	40.00	f	5	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5969	144	35	2024-10-19	4	63.00	0.06	252.00	236.88	t	5	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5970	118	33	2024-10-20	5	21.00	0.01	105.00	103.95	t	6	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5971	22	4	2024-10-20	10	10.00	0.06	100.00	94.00	t	6	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5972	34	26	2024-10-20	4	22.00	0.01	88.00	87.12	t	6	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5973	25	21	2024-10-20	6	34.00	0.04	204.00	195.84	t	6	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5974	98	30	2024-10-20	9	18.00	0.09	162.00	147.42	t	6	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5975	78	22	2024-10-20	1	54.00	0.10	54.00	48.60	t	6	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5976	6	6	2024-10-20	7	25.00	0.10	175.00	157.50	t	6	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5977	5	36	2024-10-20	7	26.50	0.07	185.50	172.52	t	6	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5978	110	36	2024-10-20	9	26.50	0.06	238.50	224.19	t	6	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5979	148	1	2024-10-20	1	30.00	0.07	30.00	27.90	t	6	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5980	135	50	2024-10-20	10	17.50	0.09	175.00	159.25	t	6	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5981	1	43	2024-10-20	10	28.00	0.03	280.00	271.60	t	6	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5982	2	20	2024-10-20	3	17.00	0.03	51.00	49.47	t	6	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5983	61	45	2024-10-20	1	59.50	0.02	59.50	58.31	t	6	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5984	112	31	2024-10-20	10	37.00	0.08	370.00	340.40	t	6	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5985	25	42	2024-10-21	3	53.00	0.01	159.00	157.41	t	0	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5986	138	16	2024-10-21	3	26.00	0.05	78.00	74.10	t	0	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5987	36	13	2024-10-21	2	23.00	0.01	46.00	45.54	t	0	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5988	58	53	2024-10-21	5	22.50	0.06	112.50	105.75	t	0	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5989	67	26	2024-10-21	8	22.00	0.05	176.00	167.20	t	0	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5990	122	35	2024-10-21	6	63.00	0.10	378.00	340.20	t	0	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5991	108	10	2024-10-21	3	15.00	0.01	45.00	44.55	t	0	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5992	101	26	2024-10-21	5	22.00	0.06	110.00	103.40	t	0	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5993	10	37	2024-10-21	2	88.00	0.01	176.00	174.24	t	0	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5994	31	10	2024-10-21	7	15.00	0.04	105.00	100.80	t	0	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5995	142	9	2024-10-21	1	36.00	0.07	36.00	33.48	t	0	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5996	19	41	2024-10-21	9	33.50	0.01	301.50	298.49	t	0	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5997	97	50	2024-10-22	3	17.50	0.01	52.50	51.98	t	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5998	61	22	2024-10-22	8	54.00	0.04	432.00	414.72	t	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
5999	73	33	2024-10-22	10	21.00	0.06	210.00	197.40	t	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6000	45	1	2024-10-22	9	30.00	0.08	270.00	248.40	t	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6001	65	13	2024-10-22	5	23.00	0.03	115.00	111.55	t	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6002	147	52	2024-10-22	9	47.50	0.02	427.50	418.95	t	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6003	128	26	2024-10-22	5	22.00	0.00	110.00	110.00	f	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6004	148	11	2024-10-22	9	32.00	0.06	288.00	270.72	t	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6005	132	53	2024-10-22	8	22.50	0.07	180.00	167.40	t	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6006	124	35	2024-10-22	8	63.00	0.03	504.00	488.88	t	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6007	93	1	2024-10-22	6	30.00	0.07	180.00	167.40	t	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6008	100	44	2024-10-23	10	10.50	0.06	105.00	98.70	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6009	28	24	2024-10-23	9	11.00	0.10	99.00	89.10	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6010	74	47	2024-10-23	5	82.50	0.06	412.50	387.75	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6011	79	13	2024-10-23	5	23.00	0.08	115.00	105.80	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6012	75	53	2024-10-23	2	22.50	0.05	45.00	42.75	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6013	88	25	2024-10-23	10	65.00	0.09	650.00	591.50	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6014	90	38	2024-10-23	9	39.00	0.05	351.00	333.45	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6015	16	40	2024-10-23	4	13.00	0.08	52.00	47.84	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6016	24	19	2024-10-23	10	38.00	0.01	380.00	376.20	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6017	5	32	2024-10-23	4	48.00	0.06	192.00	180.48	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6018	115	18	2024-10-23	8	43.00	0.05	344.00	326.80	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6019	111	32	2024-10-23	3	48.00	0.00	144.00	144.00	f	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6020	113	38	2024-10-23	6	39.00	0.03	234.00	226.98	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6021	36	27	2024-10-23	4	85.00	0.03	340.00	329.80	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6022	132	3	2024-10-23	6	20.00	0.10	120.00	108.00	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6023	89	15	2024-10-23	7	70.00	0.07	490.00	455.70	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6024	66	14	2024-10-23	1	12.00	0.05	12.00	11.40	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6025	13	37	2024-10-23	9	88.00	0.01	792.00	784.08	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6026	139	53	2024-10-24	6	22.50	0.08	135.00	124.20	t	3	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6027	146	53	2024-10-24	2	22.50	0.09	45.00	40.95	t	3	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6028	113	15	2024-10-24	1	70.00	0.09	70.00	63.70	t	3	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6029	6	47	2024-10-24	6	82.50	0.01	495.00	490.05	t	3	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6030	114	17	2024-10-24	7	80.00	0.01	560.00	554.40	t	3	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6031	26	11	2024-10-24	2	32.00	0.00	64.00	64.00	f	3	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6032	78	5	2024-10-24	6	60.00	0.04	360.00	345.60	t	3	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6033	25	48	2024-10-24	1	44.50	0.06	44.50	41.83	t	3	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6034	63	13	2024-10-24	5	23.00	0.03	115.00	111.55	t	3	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6035	109	27	2024-10-24	7	85.00	0.05	595.00	565.25	t	3	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6036	76	44	2024-10-24	9	10.50	0.08	94.50	86.94	t	3	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6037	92	16	2024-10-24	9	26.00	0.03	234.00	226.98	t	3	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6038	13	19	2024-10-24	6	38.00	0.08	228.00	209.76	t	3	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6039	92	14	2024-10-24	9	12.00	0.07	108.00	100.44	t	3	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6040	54	49	2024-10-24	7	39.50	0.02	276.50	270.97	t	3	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6041	40	11	2024-10-24	4	32.00	0.07	128.00	119.04	t	3	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6042	100	33	2024-10-24	1	21.00	0.06	21.00	19.74	t	3	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6043	4	18	2024-10-25	10	43.00	0.09	430.00	391.30	t	4	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6044	57	10	2024-10-25	3	15.00	0.05	45.00	42.75	t	4	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6045	137	11	2024-10-25	7	32.00	0.06	224.00	210.56	t	4	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6046	123	46	2024-10-25	5	25.50	0.01	127.50	126.23	t	4	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6047	88	10	2024-10-25	4	15.00	0.00	60.00	60.00	f	4	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6048	22	28	2024-10-25	9	46.00	0.10	414.00	372.60	t	4	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6049	38	12	2024-10-25	8	44.00	0.02	352.00	344.96	t	4	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6050	52	43	2024-10-25	4	28.00	0.09	112.00	101.92	t	4	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6051	124	46	2024-10-25	4	25.50	0.05	102.00	96.90	t	4	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6052	44	17	2024-10-25	2	80.00	0.09	160.00	145.60	t	4	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6053	98	40	2024-10-25	3	13.00	0.02	39.00	38.22	t	4	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6054	15	20	2024-10-25	7	17.00	0.08	119.00	109.48	t	4	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6055	50	43	2024-10-25	7	28.00	0.08	196.00	180.32	t	4	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6056	127	6	2024-10-25	5	25.00	0.03	125.00	121.25	t	4	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6057	12	53	2024-10-25	7	22.50	0.03	157.50	152.78	t	4	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6058	19	53	2024-10-25	6	22.50	0.08	135.00	124.20	t	4	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6059	37	38	2024-10-25	4	39.00	0.08	156.00	143.52	t	4	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6060	122	33	2024-10-25	10	21.00	0.07	210.00	195.30	t	4	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6061	138	5	2024-10-25	2	60.00	0.10	120.00	108.00	t	4	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6062	66	39	2024-10-25	1	35.00	0.08	35.00	32.20	t	4	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6063	36	41	2024-10-25	8	33.50	0.05	268.00	254.60	t	4	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6064	90	41	2024-10-25	3	33.50	0.07	100.50	93.46	t	4	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6065	88	42	2024-10-25	5	53.00	0.02	265.00	259.70	t	4	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6066	60	11	2024-10-26	5	32.00	0.06	160.00	150.40	t	5	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6067	67	41	2024-10-26	5	33.50	0.03	167.50	162.48	t	5	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6068	89	52	2024-10-26	4	47.50	0.08	190.00	174.80	t	5	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6069	29	1	2024-10-26	4	30.00	0.02	120.00	117.60	t	5	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6070	31	25	2024-10-26	10	65.00	0.05	650.00	617.50	t	5	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6071	18	29	2024-10-26	2	40.00	0.07	80.00	74.40	t	5	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6072	3	38	2024-10-26	9	39.00	0.09	351.00	319.41	t	5	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6073	24	16	2024-10-26	4	26.00	0.06	104.00	97.76	t	5	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6074	16	41	2024-10-26	8	33.50	0.04	268.00	257.28	t	5	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6075	20	12	2024-10-26	5	44.00	0.02	220.00	215.60	t	5	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6076	40	31	2024-10-26	2	37.00	0.09	74.00	67.34	t	5	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6077	95	36	2024-10-26	8	26.50	0.06	212.00	199.28	t	5	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6078	13	5	2024-10-26	5	60.00	0.04	300.00	288.00	t	5	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6079	38	16	2024-10-26	3	26.00	0.09	78.00	70.98	t	5	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6080	38	50	2024-10-27	1	17.50	0.02	17.50	17.15	t	6	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6081	59	26	2024-10-27	7	22.00	0.00	154.00	154.00	f	6	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6082	38	40	2024-10-27	8	13.00	0.10	104.00	93.60	t	6	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6083	70	13	2024-10-27	3	23.00	0.03	69.00	66.93	t	6	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6084	61	11	2024-10-27	2	32.00	0.04	64.00	61.44	t	6	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6085	5	17	2024-10-27	8	80.00	0.09	640.00	582.40	t	6	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6086	23	2	2024-10-27	10	50.00	0.00	500.00	500.00	f	6	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6087	121	47	2024-10-27	8	82.50	0.01	660.00	653.40	t	6	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6088	84	41	2024-10-27	1	33.50	0.08	33.50	30.82	t	6	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6089	11	29	2024-10-27	2	40.00	0.08	80.00	73.60	t	6	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6090	25	19	2024-10-27	4	38.00	0.00	152.00	152.00	f	6	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6091	63	13	2024-10-27	5	23.00	0.08	115.00	105.80	t	6	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6092	20	36	2024-10-27	7	26.50	0.03	185.50	179.94	t	6	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6093	60	10	2024-10-27	10	15.00	0.04	150.00	144.00	t	6	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6094	57	45	2024-10-27	3	59.50	0.08	178.50	164.22	t	6	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6095	150	38	2024-10-27	4	39.00	0.09	156.00	141.96	t	6	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6096	41	33	2024-10-27	5	21.00	0.06	105.00	98.70	t	6	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6097	136	24	2024-10-27	10	11.00	0.09	110.00	100.10	t	6	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6098	136	45	2024-10-27	3	59.50	0.07	178.50	166.01	t	6	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6099	141	7	2024-10-28	10	90.00	0.03	900.00	873.00	t	0	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6100	56	23	2024-10-28	2	24.00	0.06	48.00	45.12	t	0	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6101	22	2	2024-10-28	7	50.00	0.05	350.00	332.50	t	0	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6102	150	47	2024-10-28	1	82.50	0.04	82.50	79.20	t	0	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6103	88	16	2024-10-28	4	26.00	0.09	104.00	94.64	t	0	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6104	91	48	2024-10-28	3	44.50	0.02	133.50	130.83	t	0	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6105	69	1	2024-10-28	2	30.00	0.04	60.00	57.60	t	0	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6106	36	24	2024-10-28	6	11.00	0.08	66.00	60.72	t	0	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6107	26	38	2024-10-28	3	39.00	0.03	117.00	113.49	t	0	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6108	20	4	2024-10-28	4	10.00	0.05	40.00	38.00	t	0	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6109	81	48	2024-10-28	2	44.50	0.10	89.00	80.10	t	0	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6110	79	35	2024-10-28	1	63.00	0.05	63.00	59.85	t	0	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6111	71	36	2024-10-28	10	26.50	0.05	265.00	251.75	t	0	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6112	41	27	2024-10-28	10	85.00	0.05	850.00	807.50	t	0	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6113	71	22	2024-10-28	7	54.00	0.06	378.00	355.32	t	0	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6114	110	22	2024-10-28	8	54.00	0.02	432.00	423.36	t	0	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6115	134	20	2024-10-28	5	17.00	0.02	85.00	83.30	t	0	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6116	14	44	2024-10-28	9	10.50	0.09	94.50	86.00	t	0	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6117	53	7	2024-10-29	6	90.00	0.03	540.00	523.80	t	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6118	4	22	2024-10-29	9	54.00	0.04	486.00	466.56	t	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6119	120	36	2024-10-29	7	26.50	0.06	185.50	174.37	t	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6120	47	32	2024-10-29	3	48.00	0.03	144.00	139.68	t	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6121	61	20	2024-10-29	2	17.00	0.07	34.00	31.62	t	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6122	77	45	2024-10-29	6	59.50	0.02	357.00	349.86	t	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6123	21	13	2024-10-29	8	23.00	0.05	184.00	174.80	t	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6124	11	2	2024-10-29	1	50.00	0.03	50.00	48.50	t	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6125	59	18	2024-10-29	10	43.00	0.06	430.00	404.20	t	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6126	103	35	2024-10-29	4	63.00	0.08	252.00	231.84	t	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6127	47	4	2024-10-29	6	10.00	0.06	60.00	56.40	t	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6128	9	8	2024-10-29	5	40.00	0.07	200.00	186.00	t	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6129	37	30	2024-10-29	5	18.00	0.06	90.00	84.60	t	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6130	86	7	2024-10-29	9	90.00	0.04	810.00	777.60	t	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6131	125	26	2024-10-29	6	22.00	0.04	132.00	126.72	t	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6132	94	18	2024-10-29	7	43.00	0.03	301.00	291.97	t	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6133	70	24	2024-10-29	7	11.00	0.05	77.00	73.15	t	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6134	39	49	2024-10-29	5	39.50	0.03	197.50	191.58	t	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6135	87	30	2024-10-29	5	18.00	0.01	90.00	89.10	t	1	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6136	96	43	2024-10-30	7	28.00	0.03	196.00	190.12	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6137	32	28	2024-10-30	7	46.00	0.04	322.00	309.12	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6138	44	28	2024-10-30	7	46.00	0.06	322.00	302.68	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6139	94	37	2024-10-30	4	88.00	0.08	352.00	323.84	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6140	19	50	2024-10-30	5	17.50	0.08	87.50	80.50	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6141	40	40	2024-10-30	5	13.00	0.03	65.00	63.05	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6142	59	8	2024-10-30	5	40.00	0.06	200.00	188.00	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6143	135	52	2024-10-30	9	47.50	0.02	427.50	418.95	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6144	6	22	2024-10-30	4	54.00	0.05	216.00	205.20	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6145	97	6	2024-10-30	2	25.00	0.06	50.00	47.00	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6146	53	10	2024-10-30	9	15.00	0.06	135.00	126.90	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6147	23	23	2024-10-30	4	24.00	0.06	96.00	90.24	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6148	44	50	2024-10-30	7	17.50	0.03	122.50	118.83	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6149	49	28	2024-10-30	5	46.00	0.06	230.00	216.20	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6150	4	19	2024-10-30	7	38.00	0.05	266.00	252.70	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6151	130	24	2024-10-30	9	11.00	0.05	99.00	94.05	t	2	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6152	53	49	2024-10-31	5	39.50	0.06	197.50	185.65	t	3	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6153	11	27	2024-10-31	2	85.00	0.03	170.00	164.90	t	3	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6154	64	16	2024-10-31	2	26.00	0.08	52.00	47.84	t	3	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6155	75	15	2024-10-31	1	70.00	0.05	70.00	66.50	t	3	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6156	111	11	2024-10-31	1	32.00	0.01	32.00	31.68	t	3	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6157	74	8	2024-10-31	2	40.00	0.07	80.00	74.40	t	3	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6158	149	33	2024-10-31	4	21.00	0.04	84.00	80.64	t	3	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6159	26	29	2024-10-31	10	40.00	0.08	400.00	368.00	t	3	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6160	57	34	2024-10-31	7	9.50	0.02	66.50	65.17	t	3	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6161	95	12	2024-10-31	3	44.00	0.05	132.00	125.40	t	3	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6162	103	36	2024-10-31	2	26.50	0.07	53.00	49.29	t	3	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6163	36	22	2024-10-31	2	54.00	0.03	108.00	104.76	t	3	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6164	105	14	2024-10-31	9	12.00	0.07	108.00	100.44	t	3	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6165	62	23	2024-10-31	9	24.00	0.08	216.00	198.72	t	3	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6166	119	32	2024-10-31	8	48.00	0.07	384.00	357.12	t	3	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6167	65	11	2024-10-31	6	32.00	0.07	192.00	178.56	t	3	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6168	51	44	2024-10-31	7	10.50	0.02	73.50	72.03	t	3	10	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6169	150	30	2024-11-01	10	18.00	0.06	180.00	169.20	t	4	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6170	129	17	2024-11-01	5	80.00	0.01	400.00	396.00	t	4	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6171	53	27	2024-11-01	8	85.00	0.01	680.00	673.20	t	4	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6172	32	7	2024-11-01	4	90.00	0.04	360.00	345.60	t	4	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6173	44	20	2024-11-01	3	17.00	0.08	51.00	46.92	t	4	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6174	22	31	2024-11-01	1	37.00	0.04	37.00	35.52	t	4	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6175	22	21	2024-11-01	8	34.00	0.06	272.00	255.68	t	4	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6176	98	33	2024-11-01	1	21.00	0.04	21.00	20.16	t	4	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6177	6	28	2024-11-01	9	46.00	0.05	414.00	393.30	t	4	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6178	95	49	2024-11-01	1	39.50	0.03	39.50	38.32	t	4	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6179	108	10	2024-11-01	7	15.00	0.09	105.00	95.55	t	4	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6180	112	5	2024-11-01	3	60.00	0.03	180.00	174.60	t	4	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6181	37	30	2024-11-02	10	18.00	0.05	180.00	171.00	t	5	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6182	45	18	2024-11-02	4	43.00	0.01	172.00	170.28	t	5	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6183	65	10	2024-11-02	8	15.00	0.08	120.00	110.40	t	5	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6184	133	32	2024-11-02	8	48.00	0.03	384.00	372.48	t	5	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6185	102	30	2024-11-02	1	18.00	0.09	18.00	16.38	t	5	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6186	87	46	2024-11-02	3	25.50	0.07	76.50	71.15	t	5	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6187	45	46	2024-11-02	2	25.50	0.02	51.00	49.98	t	5	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6188	91	41	2024-11-02	5	33.50	0.05	167.50	159.13	t	5	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6189	77	17	2024-11-02	4	80.00	0.02	320.00	313.60	t	5	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6190	95	38	2024-11-02	5	39.00	0.01	195.00	193.05	t	5	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6191	140	8	2024-11-02	6	40.00	0.05	240.00	228.00	t	5	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6192	82	12	2024-11-02	9	44.00	0.05	396.00	376.20	t	5	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6193	134	15	2024-11-02	4	70.00	0.03	280.00	271.60	t	5	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6194	101	53	2024-11-02	5	22.50	0.07	112.50	104.63	t	5	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6195	50	11	2024-11-02	5	32.00	0.05	160.00	152.00	t	5	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6196	62	28	2024-11-02	3	46.00	0.09	138.00	125.58	t	5	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6197	148	49	2024-11-02	1	39.50	0.07	39.50	36.74	t	5	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6198	41	25	2024-11-02	2	65.00	0.01	130.00	128.70	t	5	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6199	37	44	2024-11-03	4	10.50	0.01	42.00	41.58	t	6	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6200	11	42	2024-11-03	3	53.00	0.07	159.00	147.87	t	6	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6201	92	38	2024-11-03	3	39.00	0.03	117.00	113.49	t	6	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6202	69	42	2024-11-03	8	53.00	0.03	424.00	411.28	t	6	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6203	115	27	2024-11-03	10	85.00	0.05	850.00	807.50	t	6	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6204	50	20	2024-11-03	7	17.00	0.07	119.00	110.67	t	6	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6205	7	24	2024-11-03	5	11.00	0.09	55.00	50.05	t	6	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6206	72	47	2024-11-03	6	82.50	0.08	495.00	455.40	t	6	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6207	7	49	2024-11-03	6	39.50	0.02	237.00	232.26	t	6	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6208	117	20	2024-11-03	3	17.00	0.06	51.00	47.94	t	6	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6209	138	40	2024-11-04	7	13.00	0.08	91.00	83.72	t	0	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6210	9	5	2024-11-04	9	60.00	0.03	540.00	523.80	t	0	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6211	115	3	2024-11-04	2	20.00	0.02	40.00	39.20	t	0	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6212	61	10	2024-11-04	8	15.00	0.04	120.00	115.20	t	0	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6213	23	20	2024-11-04	3	17.00	0.07	51.00	47.43	t	0	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6214	82	8	2024-11-04	4	40.00	0.08	160.00	147.20	t	0	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6215	121	20	2024-11-04	6	17.00	0.05	102.00	96.90	t	0	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6216	14	16	2024-11-04	7	26.00	0.04	182.00	174.72	t	0	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6217	120	6	2024-11-04	8	25.00	0.05	200.00	190.00	t	0	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6218	121	53	2024-11-04	5	22.50	0.10	112.50	101.25	t	0	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6219	98	21	2024-11-04	1	34.00	0.06	34.00	31.96	t	0	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6220	126	21	2024-11-04	9	34.00	0.06	306.00	287.64	t	0	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6221	44	14	2024-11-04	4	12.00	0.07	48.00	44.64	t	0	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6222	125	1	2024-11-04	7	30.00	0.04	210.00	201.60	t	0	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6223	64	32	2024-11-04	2	48.00	0.01	96.00	95.04	t	0	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6224	19	43	2024-11-04	3	28.00	0.10	84.00	75.60	t	0	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6225	71	43	2024-11-04	4	28.00	0.03	112.00	108.64	t	0	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6226	73	9	2024-11-04	9	36.00	0.07	324.00	301.32	t	0	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6227	145	21	2024-11-04	8	34.00	0.09	272.00	247.52	t	0	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6228	127	39	2024-11-04	2	35.00	0.07	70.00	65.10	t	0	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6229	7	36	2024-11-04	5	26.50	0.07	132.50	123.23	t	0	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6230	55	51	2024-11-05	6	31.50	0.06	189.00	177.66	t	1	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6231	11	53	2024-11-05	6	22.50	0.05	135.00	128.25	t	1	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6232	17	6	2024-11-05	9	25.00	0.06	225.00	211.50	t	1	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6233	100	18	2024-11-05	3	43.00	0.10	129.00	116.10	t	1	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6234	71	36	2024-11-05	1	26.50	0.09	26.50	24.12	t	1	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6235	147	18	2024-11-05	9	43.00	0.02	387.00	379.26	t	1	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6236	49	10	2024-11-05	9	15.00	0.05	135.00	128.25	t	1	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6237	46	53	2024-11-05	5	22.50	0.07	112.50	104.63	t	1	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6238	119	6	2024-11-05	5	25.00	0.02	125.00	122.50	t	1	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6239	33	40	2024-11-05	7	13.00	0.06	91.00	85.54	t	1	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6240	117	51	2024-11-05	7	31.50	0.02	220.50	216.09	t	1	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6241	66	36	2024-11-05	10	26.50	0.03	265.00	257.05	t	1	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6242	18	9	2024-11-05	2	36.00	0.02	72.00	70.56	t	1	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6243	104	22	2024-11-05	8	54.00	0.01	432.00	427.68	t	1	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6244	32	16	2024-11-05	2	26.00	0.01	52.00	51.48	t	1	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6245	143	42	2024-11-05	6	53.00	0.09	318.00	289.38	t	1	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6246	34	29	2024-11-05	3	40.00	0.05	120.00	114.00	t	1	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6247	69	13	2024-11-06	1	23.00	0.07	23.00	21.39	t	2	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6248	9	2	2024-11-06	2	50.00	0.05	100.00	95.00	t	2	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6249	21	40	2024-11-06	1	13.00	0.09	13.00	11.83	t	2	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6250	2	28	2024-11-06	10	46.00	0.09	460.00	418.60	t	2	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6251	100	50	2024-11-06	1	17.50	0.07	17.50	16.28	t	2	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6252	48	52	2024-11-06	7	47.50	0.00	332.50	332.50	f	2	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6253	139	44	2024-11-06	8	10.50	0.04	84.00	80.64	t	2	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6254	102	21	2024-11-06	8	34.00	0.03	272.00	263.84	t	2	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6255	3	22	2024-11-06	6	54.00	0.08	324.00	298.08	t	2	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6256	32	52	2024-11-06	2	47.50	0.03	95.00	92.15	t	2	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6257	119	19	2024-11-06	3	38.00	0.08	114.00	104.88	t	2	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6258	122	42	2024-11-06	4	53.00	0.02	212.00	207.76	t	2	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6259	70	4	2024-11-06	5	10.00	0.09	50.00	45.50	t	2	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6260	91	3	2024-11-07	6	20.00	0.03	120.00	116.40	t	3	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6261	39	27	2024-11-07	5	85.00	0.06	425.00	399.50	t	3	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6262	20	20	2024-11-07	3	17.00	0.00	51.00	51.00	f	3	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6263	15	49	2024-11-07	3	39.50	0.09	118.50	107.84	t	3	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6264	130	52	2024-11-07	2	47.50	0.08	95.00	87.40	t	3	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6265	54	45	2024-11-07	3	59.50	0.00	178.50	178.50	f	3	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6266	24	7	2024-11-07	6	90.00	0.06	540.00	507.60	t	3	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6267	93	51	2024-11-07	10	31.50	0.08	315.00	289.80	t	3	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6268	106	1	2024-11-07	10	30.00	0.04	300.00	288.00	t	3	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6269	143	31	2024-11-07	5	37.00	0.06	185.00	173.90	t	3	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6270	102	12	2024-11-07	6	44.00	0.04	264.00	253.44	t	3	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6271	29	6	2024-11-07	9	25.00	0.03	225.00	218.25	t	3	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6272	42	10	2024-11-07	10	15.00	0.07	150.00	139.50	t	3	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6273	18	39	2024-11-07	7	35.00	0.10	245.00	220.50	t	3	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6274	28	39	2024-11-07	10	35.00	0.01	350.00	346.50	t	3	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6275	138	22	2024-11-07	7	54.00	0.01	378.00	374.22	t	3	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6276	106	45	2024-11-07	4	59.50	0.03	238.00	230.86	t	3	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6277	134	42	2024-11-07	3	53.00	0.04	159.00	152.64	t	3	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6278	28	6	2024-11-08	2	25.00	0.02	50.00	49.00	t	4	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6279	63	23	2024-11-08	9	24.00	0.07	216.00	200.88	t	4	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6280	93	41	2024-11-08	7	33.50	0.01	234.50	232.16	t	4	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6281	4	42	2024-11-08	4	53.00	0.06	212.00	199.28	t	4	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6282	6	29	2024-11-08	1	40.00	0.09	40.00	36.40	t	4	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6283	31	12	2024-11-08	5	44.00	0.06	220.00	206.80	t	4	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6284	37	14	2024-11-08	10	12.00	0.08	120.00	110.40	t	4	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6285	14	24	2024-11-08	2	11.00	0.05	22.00	20.90	t	4	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6286	84	30	2024-11-08	2	18.00	0.07	36.00	33.48	t	4	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6287	121	10	2024-11-08	6	15.00	0.09	90.00	81.90	t	4	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6288	1	32	2024-11-08	8	48.00	0.01	384.00	380.16	t	4	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6289	21	40	2024-11-08	5	13.00	0.09	65.00	59.15	t	4	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6290	100	3	2024-11-08	7	20.00	0.02	140.00	137.20	t	4	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6291	89	40	2024-11-08	10	13.00	0.01	130.00	128.70	t	4	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6292	112	20	2024-11-08	10	17.00	0.00	170.00	170.00	f	4	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6293	119	31	2024-11-08	6	37.00	0.08	222.00	204.24	t	4	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6294	35	50	2024-11-08	9	17.50	0.03	157.50	152.78	t	4	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6295	31	20	2024-11-08	3	17.00	0.07	51.00	47.43	t	4	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6296	1	15	2024-11-08	5	70.00	0.04	350.00	336.00	t	4	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6297	23	14	2024-11-08	10	12.00	0.09	120.00	109.20	t	4	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6298	87	9	2024-11-08	1	36.00	0.07	36.00	33.48	t	4	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6299	7	1	2024-11-09	9	30.00	0.06	270.00	253.80	t	5	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6300	51	47	2024-11-09	3	82.50	0.05	247.50	235.13	t	5	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6301	142	39	2024-11-09	1	35.00	0.04	35.00	33.60	t	5	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6302	8	31	2024-11-09	2	37.00	0.05	74.00	70.30	t	5	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6303	118	11	2024-11-09	2	32.00	0.03	64.00	62.08	t	5	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6304	51	36	2024-11-09	8	26.50	0.04	212.00	203.52	t	5	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6305	72	37	2024-11-09	6	88.00	0.03	528.00	512.16	t	5	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6306	32	18	2024-11-09	10	43.00	0.08	430.00	395.60	t	5	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6307	46	37	2024-11-09	1	88.00	0.01	88.00	87.12	t	5	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6308	101	51	2024-11-09	6	31.50	0.05	189.00	179.55	t	5	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6309	6	53	2024-11-09	3	22.50	0.03	67.50	65.48	t	5	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6310	81	9	2024-11-09	5	36.00	0.05	180.00	171.00	t	5	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6311	123	32	2024-11-09	9	48.00	0.04	432.00	414.72	t	5	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6312	20	37	2024-11-09	7	88.00	0.09	616.00	560.56	t	5	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6313	76	30	2024-11-09	8	18.00	0.07	144.00	133.92	t	5	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6314	87	39	2024-11-09	3	35.00	0.08	105.00	96.60	t	5	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6315	7	19	2024-11-10	3	38.00	0.09	114.00	103.74	t	6	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6316	35	4	2024-11-10	5	10.00	0.04	50.00	48.00	t	6	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6317	105	40	2024-11-10	7	13.00	0.02	91.00	89.18	t	6	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6318	83	10	2024-11-10	2	15.00	0.05	30.00	28.50	t	6	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6319	95	50	2024-11-10	9	17.50	0.04	157.50	151.20	t	6	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6320	62	3	2024-11-10	8	20.00	0.09	160.00	145.60	t	6	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6321	91	29	2024-11-10	5	40.00	0.06	200.00	188.00	t	6	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6322	35	46	2024-11-10	5	25.50	0.02	127.50	124.95	t	6	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6323	94	15	2024-11-10	4	70.00	0.03	280.00	271.60	t	6	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6324	150	6	2024-11-10	7	25.00	0.05	175.00	166.25	t	6	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6325	145	38	2024-11-10	10	39.00	0.05	390.00	370.50	t	6	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6326	8	17	2024-11-10	4	80.00	0.02	320.00	313.60	t	6	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6327	67	17	2024-11-10	5	80.00	0.00	400.00	400.00	f	6	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6328	103	51	2024-11-10	10	31.50	0.00	315.00	315.00	f	6	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6329	123	26	2024-11-10	5	22.00	0.09	110.00	100.10	t	6	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6330	89	37	2024-11-10	6	88.00	0.09	528.00	480.48	t	6	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6331	122	53	2024-11-10	5	22.50	0.04	112.50	108.00	t	6	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6332	1	49	2024-11-10	9	39.50	0.00	355.50	355.50	f	6	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6333	106	43	2024-11-10	10	28.00	0.00	280.00	280.00	f	6	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6334	78	31	2024-11-11	3	37.00	0.01	111.00	109.89	t	0	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6335	83	9	2024-11-11	7	36.00	0.05	252.00	239.40	t	0	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6336	68	25	2024-11-11	8	65.00	0.05	520.00	494.00	t	0	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6337	32	21	2024-11-11	2	34.00	0.08	68.00	62.56	t	0	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6338	6	32	2024-11-11	9	48.00	0.02	432.00	423.36	t	0	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6339	117	18	2024-11-11	4	43.00	0.03	172.00	166.84	t	0	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6340	109	50	2024-11-11	4	17.50	0.08	70.00	64.40	t	0	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6341	80	45	2024-11-11	9	59.50	0.06	535.50	503.37	t	0	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6342	112	39	2024-11-11	6	35.00	0.04	210.00	201.60	t	0	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6343	140	22	2024-11-11	1	54.00	0.08	54.00	49.68	t	0	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6344	56	28	2024-11-12	6	46.00	0.02	276.00	270.48	t	1	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6345	86	17	2024-11-12	5	80.00	0.08	400.00	368.00	t	1	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6346	7	11	2024-11-12	9	32.00	0.03	288.00	279.36	t	1	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6347	139	14	2024-11-12	7	12.00	0.04	84.00	80.64	t	1	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6348	19	11	2024-11-12	8	32.00	0.08	256.00	235.52	t	1	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6349	14	27	2024-11-12	9	85.00	0.09	765.00	696.15	t	1	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6350	77	3	2024-11-12	10	20.00	0.02	200.00	196.00	t	1	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6351	15	33	2024-11-12	1	21.00	0.01	21.00	20.79	t	1	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6352	80	9	2024-11-12	4	36.00	0.02	144.00	141.12	t	1	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6353	79	35	2024-11-12	7	63.00	0.06	441.00	414.54	t	1	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6354	77	39	2024-11-12	5	35.00	0.08	175.00	161.00	t	1	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6355	11	11	2024-11-12	6	32.00	0.04	192.00	184.32	t	1	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6356	35	38	2024-11-12	10	39.00	0.06	390.00	366.60	t	1	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6357	95	41	2024-11-12	1	33.50	0.04	33.50	32.16	t	1	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6358	88	46	2024-11-12	4	25.50	0.02	102.00	99.96	t	1	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6359	18	38	2024-11-12	5	39.00	0.06	195.00	183.30	t	1	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6360	130	53	2024-11-12	9	22.50	0.02	202.50	198.45	t	1	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6361	144	50	2024-11-12	3	17.50	0.04	52.50	50.40	t	1	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6362	37	22	2024-11-13	7	54.00	0.04	378.00	362.88	t	2	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6363	119	35	2024-11-13	1	63.00	0.02	63.00	61.74	t	2	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6364	63	23	2024-11-13	5	24.00	0.08	120.00	110.40	t	2	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6365	61	47	2024-11-13	4	82.50	0.08	330.00	303.60	t	2	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6366	16	4	2024-11-13	2	10.00	0.02	20.00	19.60	t	2	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6367	126	46	2024-11-13	8	25.50	0.02	204.00	199.92	t	2	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6368	95	34	2024-11-13	7	9.50	0.03	66.50	64.51	t	2	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6369	61	43	2024-11-13	4	28.00	0.10	112.00	100.80	t	2	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6370	26	7	2024-11-13	6	90.00	0.08	540.00	496.80	t	2	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6371	72	9	2024-11-13	10	36.00	0.09	360.00	327.60	t	2	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6372	100	21	2024-11-13	4	34.00	0.06	136.00	127.84	t	2	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6373	80	10	2024-11-13	4	15.00	0.00	60.00	60.00	f	2	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6374	121	43	2024-11-13	2	28.00	0.03	56.00	54.32	t	2	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6375	15	3	2024-11-13	4	20.00	0.06	80.00	75.20	t	2	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6376	150	36	2024-11-13	7	26.50	0.09	185.50	168.81	t	2	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6377	104	18	2024-11-13	5	43.00	0.08	215.00	197.80	t	2	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6378	16	51	2024-11-13	9	31.50	0.03	283.50	275.00	t	2	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6379	117	7	2024-11-13	2	90.00	0.10	180.00	162.00	t	2	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6380	81	53	2024-11-14	1	22.50	0.10	22.50	20.25	t	3	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6381	34	11	2024-11-14	4	32.00	0.02	128.00	125.44	t	3	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6382	49	45	2024-11-14	5	59.50	0.03	297.50	288.58	t	3	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6383	139	15	2024-11-14	8	70.00	0.07	560.00	520.80	t	3	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6384	132	52	2024-11-14	3	47.50	0.01	142.50	141.08	t	3	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6385	80	5	2024-11-14	3	60.00	0.08	180.00	165.60	t	3	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6386	53	4	2024-11-14	5	10.00	0.04	50.00	48.00	t	3	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6387	65	21	2024-11-14	6	34.00	0.07	204.00	189.72	t	3	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6388	6	1	2024-11-14	4	30.00	0.10	120.00	108.00	t	3	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6389	57	6	2024-11-14	1	25.00	0.10	25.00	22.50	t	3	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6390	97	26	2024-11-14	2	22.00	0.03	44.00	42.68	t	3	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6391	59	45	2024-11-14	5	59.50	0.01	297.50	294.53	t	3	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6392	105	30	2024-11-14	10	18.00	0.08	180.00	165.60	t	3	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6393	115	16	2024-11-14	8	26.00	0.06	208.00	195.52	t	3	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6394	89	47	2024-11-15	9	82.50	0.08	742.50	683.10	t	4	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6395	91	34	2024-11-15	8	9.50	0.02	76.00	74.48	t	4	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6396	29	33	2024-11-15	9	21.00	0.07	189.00	175.77	t	4	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6397	130	35	2024-11-15	6	63.00	0.09	378.00	343.98	t	4	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6398	34	27	2024-11-15	8	85.00	0.01	680.00	673.20	t	4	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6399	145	48	2024-11-15	2	44.50	0.00	89.00	89.00	f	4	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6400	121	44	2024-11-15	6	10.50	0.01	63.00	62.37	t	4	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6401	133	6	2024-11-15	1	25.00	0.05	25.00	23.75	t	4	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6402	42	30	2024-11-15	10	18.00	0.02	180.00	176.40	t	4	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6403	82	16	2024-11-15	7	26.00	0.08	182.00	167.44	t	4	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6404	55	3	2024-11-15	2	20.00	0.07	40.00	37.20	t	4	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6405	69	47	2024-11-15	5	82.50	0.08	412.50	379.50	t	4	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6406	130	22	2024-11-15	3	54.00	0.10	162.00	145.80	t	4	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6407	115	10	2024-11-15	2	15.00	0.09	30.00	27.30	t	4	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6408	62	34	2024-11-15	8	9.50	0.00	76.00	76.00	f	4	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6409	66	46	2024-11-15	7	25.50	0.09	178.50	162.44	t	4	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6410	122	24	2024-11-15	1	11.00	0.02	11.00	10.78	t	4	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6411	130	16	2024-11-15	2	26.00	0.02	52.00	50.96	t	4	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6412	80	22	2024-11-16	5	54.00	0.01	270.00	267.30	t	5	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6413	31	1	2024-11-16	1	30.00	0.03	30.00	29.10	t	5	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6414	119	21	2024-11-16	3	34.00	0.09	102.00	92.82	t	5	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6415	141	17	2024-11-16	10	80.00	0.07	800.00	744.00	t	5	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6416	10	41	2024-11-16	1	33.50	0.06	33.50	31.49	t	5	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6417	134	24	2024-11-16	8	11.00	0.05	88.00	83.60	t	5	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6418	67	22	2024-11-16	9	54.00	0.03	486.00	471.42	t	5	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6419	78	28	2024-11-16	4	46.00	0.09	184.00	167.44	t	5	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6420	100	25	2024-11-16	10	65.00	0.04	650.00	624.00	t	5	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6421	53	17	2024-11-16	8	80.00	0.02	640.00	627.20	t	5	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6422	95	34	2024-11-16	3	9.50	0.04	28.50	27.36	t	5	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6423	31	35	2024-11-17	6	63.00	0.04	378.00	362.88	t	6	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6424	37	11	2024-11-17	7	32.00	0.08	224.00	206.08	t	6	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6425	62	14	2024-11-17	5	12.00	0.04	60.00	57.60	t	6	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6426	49	9	2024-11-17	8	36.00	0.04	288.00	276.48	t	6	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6427	29	7	2024-11-17	10	90.00	0.01	900.00	891.00	t	6	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6428	33	30	2024-11-17	4	18.00	0.08	72.00	66.24	t	6	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6429	1	14	2024-11-17	5	12.00	0.03	60.00	58.20	t	6	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6430	79	27	2024-11-17	3	85.00	0.00	255.00	255.00	f	6	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6431	22	51	2024-11-17	4	31.50	0.02	126.00	123.48	t	6	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6432	3	32	2024-11-17	5	48.00	0.02	240.00	235.20	t	6	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6433	73	26	2024-11-17	5	22.00	0.10	110.00	99.00	t	6	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6434	89	22	2024-11-17	7	54.00	0.03	378.00	366.66	t	6	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6435	44	26	2024-11-17	5	22.00	0.07	110.00	102.30	t	6	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6436	114	28	2024-11-18	1	46.00	0.03	46.00	44.62	t	0	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6437	69	27	2024-11-18	6	85.00	0.01	510.00	504.90	t	0	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6438	15	35	2024-11-18	2	63.00	0.07	126.00	117.18	t	0	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6439	139	25	2024-11-18	8	65.00	0.07	520.00	483.60	t	0	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6440	3	27	2024-11-18	1	85.00	0.02	85.00	83.30	t	0	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6441	75	46	2024-11-18	4	25.50	0.08	102.00	93.84	t	0	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6442	125	43	2024-11-18	1	28.00	0.02	28.00	27.44	t	0	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6443	69	47	2024-11-18	4	82.50	0.06	330.00	310.20	t	0	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6444	55	43	2024-11-18	6	28.00	0.04	168.00	161.28	t	0	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6445	84	38	2024-11-18	5	39.00	0.02	195.00	191.10	t	0	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6446	85	49	2024-11-18	2	39.50	0.09	79.00	71.89	t	0	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6447	40	7	2024-11-18	4	90.00	0.09	360.00	327.60	t	0	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6448	61	14	2024-11-18	5	12.00	0.07	60.00	55.80	t	0	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6449	133	10	2024-11-19	6	15.00	0.01	90.00	89.10	t	1	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6450	59	10	2024-11-19	2	15.00	0.05	30.00	28.50	t	1	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6451	24	3	2024-11-19	8	20.00	0.02	160.00	156.80	t	1	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6452	129	28	2024-11-19	9	46.00	0.03	414.00	401.58	t	1	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6453	54	31	2024-11-19	9	37.00	0.04	333.00	319.68	t	1	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6454	112	22	2024-11-19	3	54.00	0.06	162.00	152.28	t	1	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6455	17	21	2024-11-19	9	34.00	0.09	306.00	278.46	t	1	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6456	88	47	2024-11-19	8	82.50	0.02	660.00	646.80	t	1	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6457	104	34	2024-11-19	10	9.50	0.04	95.00	91.20	t	1	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6458	140	50	2024-11-19	3	17.50	0.04	52.50	50.40	t	1	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6459	93	51	2024-11-19	6	31.50	0.07	189.00	175.77	t	1	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6460	143	45	2024-11-19	1	59.50	0.08	59.50	54.74	t	1	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6461	127	15	2024-11-19	1	70.00	0.00	70.00	70.00	f	1	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6462	45	18	2024-11-19	1	43.00	0.04	43.00	41.28	t	1	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6463	89	14	2024-11-19	5	12.00	0.02	60.00	58.80	t	1	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6464	97	16	2024-11-20	3	26.00	0.05	78.00	74.10	t	2	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6465	121	51	2024-11-20	5	31.50	0.02	157.50	154.35	t	2	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6466	118	4	2024-11-20	6	10.00	0.06	60.00	56.40	t	2	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6467	75	23	2024-11-20	3	24.00	0.06	72.00	67.68	t	2	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6468	21	45	2024-11-20	3	59.50	0.02	178.50	174.93	t	2	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6469	12	37	2024-11-20	6	88.00	0.10	528.00	475.20	t	2	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6470	59	5	2024-11-20	9	60.00	0.06	540.00	507.60	t	2	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6471	38	18	2024-11-20	6	43.00	0.03	258.00	250.26	t	2	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6472	12	50	2024-11-20	3	17.50	0.07	52.50	48.82	t	2	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6473	75	41	2024-11-20	9	33.50	0.05	301.50	286.43	t	2	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6474	20	2	2024-11-20	4	50.00	0.08	200.00	184.00	t	2	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6475	57	16	2024-11-20	6	26.00	0.04	156.00	149.76	t	2	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6476	10	40	2024-11-20	4	13.00	0.06	52.00	48.88	t	2	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6477	66	8	2024-11-20	4	40.00	0.07	160.00	148.80	t	2	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6478	10	49	2024-11-20	7	39.50	0.03	276.50	268.21	t	2	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6479	102	3	2024-11-21	5	20.00	0.08	100.00	92.00	t	3	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6480	85	13	2024-11-21	2	23.00	0.08	46.00	42.32	t	3	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6481	94	32	2024-11-21	2	48.00	0.05	96.00	91.20	t	3	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6482	3	48	2024-11-21	2	44.50	0.06	89.00	83.66	t	3	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6483	34	20	2024-11-21	1	17.00	0.09	17.00	15.47	t	3	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6484	55	39	2024-11-21	1	35.00	0.05	35.00	33.25	t	3	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6485	148	3	2024-11-21	3	20.00	0.03	60.00	58.20	t	3	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6486	38	46	2024-11-21	1	25.50	0.04	25.50	24.48	t	3	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6487	20	41	2024-11-21	5	33.50	0.07	167.50	155.77	t	3	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6488	96	8	2024-11-21	9	40.00	0.04	360.00	345.60	t	3	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6489	87	29	2024-11-21	8	40.00	0.02	320.00	313.60	t	3	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6490	57	6	2024-11-21	1	25.00	0.00	25.00	25.00	f	3	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6491	93	51	2024-11-21	5	31.50	0.08	157.50	144.90	t	3	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6492	129	34	2024-11-21	2	9.50	0.07	19.00	17.67	t	3	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6493	112	18	2024-11-21	4	43.00	0.05	172.00	163.40	t	3	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6494	144	24	2024-11-22	4	11.00	0.08	44.00	40.48	t	4	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6495	49	28	2024-11-22	3	46.00	0.08	138.00	126.96	t	4	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6496	73	41	2024-11-22	5	33.50	0.06	167.50	157.45	t	4	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6497	4	27	2024-11-22	2	85.00	0.04	170.00	163.20	t	4	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6498	7	53	2024-11-22	9	22.50	0.06	202.50	190.35	t	4	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6499	47	12	2024-11-22	4	44.00	0.02	176.00	172.48	t	4	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6500	72	38	2024-11-22	1	39.00	0.00	39.00	39.00	f	4	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6501	88	17	2024-11-22	6	80.00	0.01	480.00	475.20	t	4	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6502	15	44	2024-11-22	8	10.50	0.03	84.00	81.48	t	4	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6503	31	41	2024-11-22	10	33.50	0.01	335.00	331.65	t	4	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6504	47	1	2024-11-22	5	30.00	0.06	150.00	141.00	t	4	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6505	53	53	2024-11-22	10	22.50	0.03	225.00	218.25	t	4	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6506	25	47	2024-11-22	2	82.50	0.05	165.00	156.75	t	4	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6507	142	38	2024-11-22	8	39.00	0.02	312.00	305.76	t	4	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6508	58	29	2024-11-22	7	40.00	0.03	280.00	271.60	t	4	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6509	1	53	2024-11-23	10	22.50	0.03	225.00	218.25	t	5	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6510	61	11	2024-11-23	6	32.00	0.04	192.00	184.32	t	5	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6511	119	17	2024-11-23	3	80.00	0.07	240.00	223.20	t	5	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6512	71	26	2024-11-23	6	22.00	0.03	132.00	128.04	t	5	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6513	66	25	2024-11-23	8	65.00	0.02	520.00	509.60	t	5	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6514	77	33	2024-11-23	3	21.00	0.03	63.00	61.11	t	5	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6515	103	10	2024-11-23	7	15.00	0.07	105.00	97.65	t	5	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6516	76	47	2024-11-23	9	82.50	0.04	742.50	712.80	t	5	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6517	111	41	2024-11-23	5	33.50	0.07	167.50	155.77	t	5	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6518	7	34	2024-11-23	9	9.50	0.03	85.50	82.94	t	5	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6519	27	39	2024-11-23	10	35.00	0.00	350.00	350.00	f	5	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6520	62	34	2024-11-23	10	9.50	0.06	95.00	89.30	t	5	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6521	57	35	2024-11-23	10	63.00	0.00	630.00	630.00	f	5	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6522	114	8	2024-11-24	9	40.00	0.05	360.00	342.00	t	6	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6523	6	48	2024-11-24	9	44.50	0.04	400.50	384.48	t	6	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6524	49	20	2024-11-24	5	17.00	0.01	85.00	84.15	t	6	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6525	70	51	2024-11-24	9	31.50	0.10	283.50	255.15	t	6	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6526	114	23	2024-11-24	6	24.00	0.09	144.00	131.04	t	6	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6527	38	40	2024-11-24	3	13.00	0.09	39.00	35.49	t	6	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6528	27	29	2024-11-24	4	40.00	0.01	160.00	158.40	t	6	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6529	72	23	2024-11-24	9	24.00	0.02	216.00	211.68	t	6	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6530	67	37	2024-11-24	5	88.00	0.05	440.00	418.00	t	6	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6531	144	8	2024-11-24	3	40.00	0.02	120.00	117.60	t	6	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6532	29	41	2024-11-24	9	33.50	0.03	301.50	292.46	t	6	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6533	17	38	2024-11-24	4	39.00	0.01	156.00	154.44	t	6	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6534	109	34	2024-11-24	6	9.50	0.02	57.00	55.86	t	6	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6535	41	33	2024-11-24	6	21.00	0.06	126.00	118.44	t	6	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6536	147	49	2024-11-24	10	39.50	0.07	395.00	367.35	t	6	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6537	113	2	2024-11-24	9	50.00	0.03	450.00	436.50	t	6	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6538	41	12	2024-11-24	5	44.00	0.08	220.00	202.40	t	6	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6539	88	51	2024-11-25	1	31.50	0.04	31.50	30.24	t	0	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6540	111	45	2024-11-25	6	59.50	0.04	357.00	342.72	t	0	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6541	88	34	2024-11-25	3	9.50	0.01	28.50	28.22	t	0	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6542	89	23	2024-11-25	10	24.00	0.02	240.00	235.20	t	0	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6543	52	24	2024-11-25	3	11.00	0.05	33.00	31.35	t	0	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6544	40	2	2024-11-25	10	50.00	0.05	500.00	475.00	t	0	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6545	112	18	2024-11-25	6	43.00	0.00	258.00	258.00	f	0	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6546	125	4	2024-11-25	1	10.00	0.09	10.00	9.10	t	0	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6547	137	28	2024-11-25	8	46.00	0.03	368.00	356.96	t	0	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6548	37	2	2024-11-25	4	50.00	0.09	200.00	182.00	t	0	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6549	22	7	2024-11-25	1	90.00	0.01	90.00	89.10	t	0	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6550	102	49	2024-11-25	4	39.50	0.01	158.00	156.42	t	0	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6551	69	30	2024-11-25	5	18.00	0.03	90.00	87.30	t	0	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6552	17	48	2024-11-25	2	44.50	0.02	89.00	87.22	t	0	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6553	92	50	2024-11-25	7	17.50	0.04	122.50	117.60	t	0	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6554	11	37	2024-11-25	10	88.00	0.06	880.00	827.20	t	0	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6555	149	53	2024-11-26	4	22.50	0.06	90.00	84.60	t	1	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6556	3	27	2024-11-26	4	85.00	0.05	340.00	323.00	t	1	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6557	103	45	2024-11-26	2	59.50	0.06	119.00	111.86	t	1	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6558	54	29	2024-11-26	3	40.00	0.07	120.00	111.60	t	1	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6559	67	14	2024-11-26	10	12.00	0.02	120.00	117.60	t	1	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6560	140	1	2024-11-26	7	30.00	0.10	210.00	189.00	t	1	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6561	50	13	2024-11-26	7	23.00	0.04	161.00	154.56	t	1	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6562	59	35	2024-11-26	9	63.00	0.06	567.00	532.98	t	1	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6563	147	35	2024-11-26	10	63.00	0.05	630.00	598.50	t	1	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6564	125	44	2024-11-26	2	10.50	0.03	21.00	20.37	t	1	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6565	101	27	2024-11-26	4	85.00	0.01	340.00	336.60	t	1	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6566	126	33	2024-11-26	7	21.00	0.03	147.00	142.59	t	1	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6567	8	17	2024-11-26	9	80.00	0.07	720.00	669.60	t	1	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6568	149	50	2024-11-26	5	17.50	0.08	87.50	80.50	t	1	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6569	111	12	2024-11-27	6	44.00	0.07	264.00	245.52	t	2	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6570	3	41	2024-11-27	4	33.50	0.03	134.00	129.98	t	2	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6571	37	16	2024-11-27	7	26.00	0.09	182.00	165.62	t	2	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6572	22	52	2024-11-27	7	47.50	0.05	332.50	315.88	t	2	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6573	136	9	2024-11-27	3	36.00	0.02	108.00	105.84	t	2	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6574	71	17	2024-11-27	7	80.00	0.04	560.00	537.60	t	2	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6575	92	1	2024-11-27	6	30.00	0.03	180.00	174.60	t	2	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6576	81	36	2024-11-27	2	26.50	0.05	53.00	50.35	t	2	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6577	119	28	2024-11-27	7	46.00	0.07	322.00	299.46	t	2	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6578	43	18	2024-11-27	3	43.00	0.07	129.00	119.97	t	2	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6579	2	28	2024-11-27	10	46.00	0.03	460.00	446.20	t	2	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6580	142	9	2024-11-27	7	36.00	0.03	252.00	244.44	t	2	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6581	25	1	2024-11-27	5	30.00	0.09	150.00	136.50	t	2	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6582	66	25	2024-11-28	10	65.00	0.06	650.00	611.00	t	3	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6583	58	42	2024-11-28	5	53.00	0.07	265.00	246.45	t	3	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6584	75	48	2024-11-28	4	44.50	0.00	178.00	178.00	f	3	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6585	102	33	2024-11-28	3	21.00	0.02	63.00	61.74	t	3	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6586	105	26	2024-11-28	6	22.00	0.07	132.00	122.76	t	3	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6587	121	6	2024-11-28	2	25.00	0.01	50.00	49.50	t	3	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6588	98	51	2024-11-28	9	31.50	0.02	283.50	277.83	t	3	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6589	7	37	2024-11-28	10	88.00	0.08	880.00	809.60	t	3	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6590	87	1	2024-11-28	7	30.00	0.07	210.00	195.30	t	3	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6591	62	24	2024-11-28	3	11.00	0.03	33.00	32.01	t	3	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6592	29	12	2024-11-28	6	44.00	0.08	264.00	242.88	t	3	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6593	43	35	2024-11-28	9	63.00	0.06	567.00	532.98	t	3	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6594	17	45	2024-11-28	7	59.50	0.06	416.50	391.51	t	3	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6595	83	6	2024-11-28	2	25.00	0.10	50.00	45.00	t	3	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6596	83	28	2024-11-28	4	46.00	0.00	184.00	184.00	f	3	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6597	112	13	2024-11-28	2	23.00	0.04	46.00	44.16	t	3	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6598	55	45	2024-11-28	9	59.50	0.03	535.50	519.44	t	3	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6599	91	39	2024-11-28	8	35.00	0.09	280.00	254.80	t	3	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6600	25	8	2024-11-28	4	40.00	0.08	160.00	147.20	t	3	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6601	131	12	2024-11-28	2	44.00	0.01	88.00	87.12	t	3	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6602	56	38	2024-11-28	5	39.00	0.08	195.00	179.40	t	3	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6603	138	12	2024-11-28	7	44.00	0.03	308.00	298.76	t	3	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6604	148	33	2024-11-28	5	21.00	0.02	105.00	102.90	t	3	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6605	19	13	2024-11-28	2	23.00	0.05	46.00	43.70	t	3	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6606	89	23	2024-11-28	2	24.00	0.06	48.00	45.12	t	3	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6607	86	49	2024-11-28	5	39.50	0.01	197.50	195.53	t	3	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6608	69	53	2024-11-29	10	22.50	0.04	225.00	216.00	t	4	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6609	49	18	2024-11-29	5	43.00	0.01	215.00	212.85	t	4	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6610	142	30	2024-11-29	1	18.00	0.06	18.00	16.92	t	4	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6611	5	18	2024-11-29	8	43.00	0.06	344.00	323.36	t	4	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6612	125	21	2024-11-29	1	34.00	0.00	34.00	34.00	f	4	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6613	112	17	2024-11-29	5	80.00	0.02	400.00	392.00	t	4	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6614	88	14	2024-11-29	5	12.00	0.05	60.00	57.00	t	4	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6615	139	39	2024-11-29	3	35.00	0.01	105.00	103.95	t	4	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6616	16	16	2024-11-29	10	26.00	0.01	260.00	257.40	t	4	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6617	79	12	2024-11-29	8	44.00	0.09	352.00	320.32	t	4	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6618	52	20	2024-11-29	6	17.00	0.01	102.00	100.98	t	4	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6619	29	41	2024-11-29	4	33.50	0.09	134.00	121.94	t	4	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6620	60	34	2024-11-30	10	9.50	0.01	95.00	94.05	t	5	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6621	50	34	2024-11-30	1	9.50	0.02	9.50	9.31	t	5	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6622	130	7	2024-11-30	2	90.00	0.06	180.00	169.20	t	5	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6623	94	1	2024-11-30	9	30.00	0.07	270.00	251.10	t	5	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6624	131	22	2024-11-30	10	54.00	0.02	540.00	529.20	t	5	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6625	8	10	2024-11-30	10	15.00	0.04	150.00	144.00	t	5	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6626	89	40	2024-11-30	3	13.00	0.02	39.00	38.22	t	5	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6627	7	4	2024-11-30	4	10.00	0.05	40.00	38.00	t	5	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6628	115	46	2024-11-30	5	25.50	0.05	127.50	121.13	t	5	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6629	8	37	2024-11-30	10	88.00	0.04	880.00	844.80	t	5	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6630	90	9	2024-11-30	4	36.00	0.07	144.00	133.92	t	5	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6631	105	10	2024-11-30	10	15.00	0.05	150.00	142.50	t	5	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6632	9	33	2024-11-30	6	21.00	0.07	126.00	117.18	t	5	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6633	138	8	2024-11-30	1	40.00	0.08	40.00	36.80	t	5	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6634	121	2	2024-11-30	6	50.00	0.01	300.00	297.00	t	5	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6635	130	19	2024-11-30	7	38.00	0.07	266.00	247.38	t	5	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6636	41	1	2024-11-30	9	30.00	0.01	270.00	267.30	t	5	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6637	51	42	2024-11-30	2	53.00	0.08	106.00	97.52	t	5	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6638	44	50	2024-11-30	4	17.50	0.09	70.00	63.70	t	5	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6639	96	48	2024-11-30	10	44.50	0.02	445.00	436.10	t	5	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6640	102	27	2024-11-30	5	85.00	0.00	425.00	425.00	f	5	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6641	61	13	2024-11-30	9	23.00	0.09	207.00	188.37	t	5	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6642	31	49	2024-11-30	7	39.50	0.05	276.50	262.68	t	5	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6643	91	25	2024-11-30	8	65.00	0.03	520.00	504.40	t	5	11	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6644	84	48	2024-12-01	2	44.50	0.00	89.00	89.00	f	6	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6645	21	35	2024-12-01	8	63.00	0.03	504.00	488.88	t	6	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6646	144	28	2024-12-01	9	46.00	0.00	414.00	414.00	f	6	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6647	15	15	2024-12-01	7	70.00	0.03	490.00	475.30	t	6	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6648	140	44	2024-12-01	6	10.50	0.01	63.00	62.37	t	6	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6649	72	19	2024-12-01	8	38.00	0.09	304.00	276.64	t	6	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6650	138	30	2024-12-01	3	18.00	0.07	54.00	50.22	t	6	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6651	116	15	2024-12-01	6	70.00	0.02	420.00	411.60	t	6	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6652	35	23	2024-12-01	1	24.00	0.08	24.00	22.08	t	6	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6653	25	43	2024-12-01	8	28.00	0.01	224.00	221.76	t	6	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6654	39	20	2024-12-01	5	17.00	0.06	85.00	79.90	t	6	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6655	75	53	2024-12-01	5	22.50	0.05	112.50	106.88	t	6	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6656	75	52	2024-12-02	10	47.50	0.03	475.00	460.75	t	0	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6657	48	30	2024-12-02	5	18.00	0.08	90.00	82.80	t	0	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6658	50	29	2024-12-02	10	40.00	0.08	400.00	368.00	t	0	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6659	14	24	2024-12-02	8	11.00	0.07	88.00	81.84	t	0	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6660	129	15	2024-12-02	5	70.00	0.02	350.00	343.00	t	0	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6661	131	11	2024-12-02	5	32.00	0.06	160.00	150.40	t	0	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6662	18	21	2024-12-02	8	34.00	0.09	272.00	247.52	t	0	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6663	50	49	2024-12-02	5	39.50	0.09	197.50	179.73	t	0	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6664	33	3	2024-12-02	3	20.00	0.02	60.00	58.80	t	0	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6665	106	51	2024-12-02	10	31.50	0.07	315.00	292.95	t	0	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6666	11	38	2024-12-02	1	39.00	0.02	39.00	38.22	t	0	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6667	41	48	2024-12-02	9	44.50	0.07	400.50	372.47	t	0	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6668	11	1	2024-12-02	7	30.00	0.05	210.00	199.50	t	0	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6669	113	10	2024-12-02	4	15.00	0.04	60.00	57.60	t	0	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6670	58	7	2024-12-02	5	90.00	0.06	450.00	423.00	t	0	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6671	28	30	2024-12-02	5	18.00	0.04	90.00	86.40	t	0	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6672	124	38	2024-12-02	4	39.00	0.10	156.00	140.40	t	0	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6673	54	47	2024-12-02	9	82.50	0.05	742.50	705.38	t	0	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6674	41	8	2024-12-02	3	40.00	0.04	120.00	115.20	t	0	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6675	135	2	2024-12-02	5	50.00	0.01	250.00	247.50	t	0	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6676	112	1	2024-12-03	10	30.00	0.04	300.00	288.00	t	1	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6677	7	32	2024-12-03	8	48.00	0.07	384.00	357.12	t	1	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6678	66	34	2024-12-03	3	9.50	0.02	28.50	27.93	t	1	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6679	137	2	2024-12-03	1	50.00	0.05	50.00	47.50	t	1	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6680	25	24	2024-12-03	6	11.00	0.06	66.00	62.04	t	1	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6681	113	1	2024-12-03	4	30.00	0.01	120.00	118.80	t	1	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6682	101	11	2024-12-03	5	32.00	0.00	160.00	160.00	f	1	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6683	142	45	2024-12-03	4	59.50	0.10	238.00	214.20	t	1	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6684	87	9	2024-12-03	5	36.00	0.07	180.00	167.40	t	1	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6685	102	46	2024-12-04	2	25.50	0.03	51.00	49.47	t	2	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6686	106	31	2024-12-04	10	37.00	0.03	370.00	358.90	t	2	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6687	104	34	2024-12-04	7	9.50	0.05	66.50	63.18	t	2	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6688	125	48	2024-12-04	2	44.50	0.08	89.00	81.88	t	2	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6689	141	1	2024-12-04	8	30.00	0.03	240.00	232.80	t	2	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6690	28	3	2024-12-04	10	20.00	0.07	200.00	186.00	t	2	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6691	42	1	2024-12-04	6	30.00	0.09	180.00	163.80	t	2	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6692	23	20	2024-12-04	9	17.00	0.05	153.00	145.35	t	2	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6693	92	7	2024-12-04	6	90.00	0.01	540.00	534.60	t	2	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6694	46	33	2024-12-04	5	21.00	0.08	105.00	96.60	t	2	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6695	11	32	2024-12-04	6	48.00	0.02	288.00	282.24	t	2	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6696	134	14	2024-12-04	7	12.00	0.05	84.00	79.80	t	2	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6697	122	7	2024-12-05	1	90.00	0.09	90.00	81.90	t	3	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6698	37	43	2024-12-05	7	28.00	0.10	196.00	176.40	t	3	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6699	70	37	2024-12-05	6	88.00	0.02	528.00	517.44	t	3	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6700	70	33	2024-12-05	5	21.00	0.06	105.00	98.70	t	3	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6701	68	14	2024-12-05	8	12.00	0.02	96.00	94.08	t	3	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6702	49	1	2024-12-05	2	30.00	0.09	60.00	54.60	t	3	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6703	135	1	2024-12-05	6	30.00	0.10	180.00	162.00	t	3	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6704	5	51	2024-12-05	1	31.50	0.06	31.50	29.61	t	3	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6705	32	3	2024-12-05	5	20.00	0.04	100.00	96.00	t	3	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6706	73	27	2024-12-05	9	85.00	0.03	765.00	742.05	t	3	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6707	148	25	2024-12-05	8	65.00	0.08	520.00	478.40	t	3	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6708	71	37	2024-12-05	4	88.00	0.02	352.00	344.96	t	3	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6709	62	20	2024-12-05	8	17.00	0.04	136.00	130.56	t	3	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6710	86	23	2024-12-05	9	24.00	0.01	216.00	213.84	t	3	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6711	137	32	2024-12-05	6	48.00	0.01	288.00	285.12	t	3	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6712	19	14	2024-12-05	10	12.00	0.05	120.00	114.00	t	3	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6713	116	51	2024-12-06	9	31.50	0.03	283.50	275.00	t	4	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6714	38	3	2024-12-06	1	20.00	0.00	20.00	20.00	f	4	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6715	86	43	2024-12-06	6	28.00	0.02	168.00	164.64	t	4	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6716	59	39	2024-12-06	2	35.00	0.09	70.00	63.70	t	4	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6717	13	48	2024-12-06	4	44.50	0.03	178.00	172.66	t	4	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6718	29	21	2024-12-06	9	34.00	0.04	306.00	293.76	t	4	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6719	103	18	2024-12-06	10	43.00	0.01	430.00	425.70	t	4	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6720	23	17	2024-12-06	1	80.00	0.08	80.00	73.60	t	4	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6721	126	32	2024-12-06	3	48.00	0.03	144.00	139.68	t	4	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6722	110	34	2024-12-06	10	9.50	0.02	95.00	93.10	t	4	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6723	69	21	2024-12-06	7	34.00	0.07	238.00	221.34	t	4	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6724	16	12	2024-12-07	1	44.00	0.06	44.00	41.36	t	5	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6725	75	49	2024-12-07	2	39.50	0.06	79.00	74.26	t	5	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6726	29	24	2024-12-07	2	11.00	0.09	22.00	20.02	t	5	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6727	61	44	2024-12-07	5	10.50	0.01	52.50	51.98	t	5	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6728	123	4	2024-12-07	6	10.00	0.07	60.00	55.80	t	5	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6729	37	40	2024-12-07	8	13.00	0.09	104.00	94.64	t	5	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6730	56	37	2024-12-07	4	88.00	0.05	352.00	334.40	t	5	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6731	62	38	2024-12-07	6	39.00	0.03	234.00	226.98	t	5	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6732	14	4	2024-12-07	4	10.00	0.08	40.00	36.80	t	5	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6733	120	20	2024-12-07	7	17.00	0.02	119.00	116.62	t	5	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6734	114	40	2024-12-07	4	13.00	0.02	52.00	50.96	t	5	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6735	36	14	2024-12-07	10	12.00	0.02	120.00	117.60	t	5	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6736	145	15	2024-12-07	8	70.00	0.05	560.00	532.00	t	5	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6737	25	36	2024-12-07	2	26.50	0.05	53.00	50.35	t	5	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6738	46	30	2024-12-07	8	18.00	0.06	144.00	135.36	t	5	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6739	111	1	2024-12-07	8	30.00	0.10	240.00	216.00	t	5	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6740	146	15	2024-12-08	10	70.00	0.01	700.00	693.00	t	6	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6741	119	38	2024-12-08	5	39.00	0.04	195.00	187.20	t	6	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6742	121	40	2024-12-08	9	13.00	0.02	117.00	114.66	t	6	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6743	75	25	2024-12-08	9	65.00	0.02	585.00	573.30	t	6	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6744	21	42	2024-12-08	3	53.00	0.10	159.00	143.10	t	6	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6745	41	48	2024-12-08	5	44.50	0.04	222.50	213.60	t	6	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6746	30	8	2024-12-08	10	40.00	0.07	400.00	372.00	t	6	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6747	26	32	2024-12-08	7	48.00	0.04	336.00	322.56	t	6	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6748	70	14	2024-12-08	7	12.00	0.03	84.00	81.48	t	6	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6749	72	8	2024-12-08	9	40.00	0.04	360.00	345.60	t	6	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6750	79	4	2024-12-08	2	10.00	0.07	20.00	18.60	t	6	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6751	35	10	2024-12-08	10	15.00	0.06	150.00	141.00	t	6	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6752	17	28	2024-12-08	6	46.00	0.05	276.00	262.20	t	6	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6753	135	37	2024-12-08	1	88.00	0.04	88.00	84.48	t	6	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6754	112	26	2024-12-08	4	22.00	0.06	88.00	82.72	t	6	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6755	38	45	2024-12-08	5	59.50	0.02	297.50	291.55	t	6	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6756	10	52	2024-12-08	2	47.50	0.01	95.00	94.05	t	6	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6757	100	1	2024-12-09	3	30.00	0.04	90.00	86.40	t	0	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6758	79	18	2024-12-09	2	43.00	0.07	86.00	79.98	t	0	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6759	138	12	2024-12-09	5	44.00	0.03	220.00	213.40	t	0	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6760	34	21	2024-12-09	7	34.00	0.04	238.00	228.48	t	0	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6761	29	1	2024-12-09	6	30.00	0.04	180.00	172.80	t	0	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6762	6	11	2024-12-09	5	32.00	0.05	160.00	152.00	t	0	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6763	98	26	2024-12-09	8	22.00	0.00	176.00	176.00	f	0	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6764	65	37	2024-12-09	3	88.00	0.04	264.00	253.44	t	0	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6765	76	42	2024-12-09	5	53.00	0.00	265.00	265.00	f	0	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6766	109	33	2024-12-09	9	21.00	0.01	189.00	187.11	t	0	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6767	26	51	2024-12-09	7	31.50	0.10	220.50	198.45	t	0	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6768	72	19	2024-12-09	10	38.00	0.09	380.00	345.80	t	0	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6769	114	1	2024-12-09	4	30.00	0.07	120.00	111.60	t	0	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6770	140	19	2024-12-10	2	38.00	0.04	76.00	72.96	t	1	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6771	66	37	2024-12-10	2	88.00	0.09	176.00	160.16	t	1	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6772	31	51	2024-12-10	9	31.50	0.05	283.50	269.33	t	1	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6773	79	35	2024-12-10	1	63.00	0.06	63.00	59.22	t	1	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6774	90	30	2024-12-10	5	18.00	0.01	90.00	89.10	t	1	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6775	71	8	2024-12-10	5	40.00	0.05	200.00	190.00	t	1	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6776	52	15	2024-12-10	3	70.00	0.04	210.00	201.60	t	1	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6777	122	28	2024-12-10	1	46.00	0.06	46.00	43.24	t	1	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6778	54	17	2024-12-10	4	80.00	0.08	320.00	294.40	t	1	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6779	52	22	2024-12-10	10	54.00	0.06	540.00	507.60	t	1	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6780	65	2	2024-12-10	6	50.00	0.06	300.00	282.00	t	1	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6781	92	53	2024-12-10	3	22.50	0.10	67.50	60.75	t	1	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6782	20	1	2024-12-11	7	30.00	0.05	210.00	199.50	t	2	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6783	86	39	2024-12-11	4	35.00	0.03	140.00	135.80	t	2	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6784	54	4	2024-12-11	4	10.00	0.03	40.00	38.80	t	2	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6785	64	23	2024-12-11	10	24.00	0.06	240.00	225.60	t	2	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6786	65	46	2024-12-11	6	25.50	0.01	153.00	151.47	t	2	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6787	48	46	2024-12-11	4	25.50	0.05	102.00	96.90	t	2	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6788	121	22	2024-12-11	3	54.00	0.06	162.00	152.28	t	2	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6789	116	42	2024-12-11	4	53.00	0.03	212.00	205.64	t	2	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6790	53	48	2024-12-11	8	44.50	0.08	356.00	327.52	t	2	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6791	122	8	2024-12-11	2	40.00	0.01	80.00	79.20	t	2	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6792	90	37	2024-12-11	7	88.00	0.01	616.00	609.84	t	2	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6793	28	9	2024-12-11	1	36.00	0.01	36.00	35.64	t	2	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6794	57	18	2024-12-11	10	43.00	0.07	430.00	399.90	t	2	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6795	44	16	2024-12-11	1	26.00	0.01	26.00	25.74	t	2	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6796	55	27	2024-12-11	5	85.00	0.02	425.00	416.50	t	2	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6797	13	53	2024-12-11	7	22.50	0.03	157.50	152.78	t	2	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6798	19	13	2024-12-11	7	23.00	0.02	161.00	157.78	t	2	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6799	41	11	2024-12-12	1	32.00	0.06	32.00	30.08	t	3	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6800	77	14	2024-12-12	9	12.00	0.03	108.00	104.76	t	3	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6801	122	52	2024-12-12	5	47.50	0.07	237.50	220.87	t	3	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6802	147	47	2024-12-12	7	82.50	0.02	577.50	565.95	t	3	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6803	104	17	2024-12-12	4	80.00	0.06	320.00	300.80	t	3	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6804	2	24	2024-12-12	5	11.00	0.03	55.00	53.35	t	3	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6805	147	47	2024-12-12	4	82.50	0.06	330.00	310.20	t	3	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6806	47	38	2024-12-12	10	39.00	0.02	390.00	382.20	t	3	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6807	50	50	2024-12-12	8	17.50	0.09	140.00	127.40	t	3	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6808	110	17	2024-12-12	6	80.00	0.10	480.00	432.00	t	3	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6809	10	34	2024-12-12	3	9.50	0.01	28.50	28.22	t	3	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6810	142	15	2024-12-12	8	70.00	0.01	560.00	554.40	t	3	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6811	26	45	2024-12-12	1	59.50	0.06	59.50	55.93	t	3	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6812	149	9	2024-12-12	1	36.00	0.04	36.00	34.56	t	3	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6813	14	47	2024-12-12	1	82.50	0.01	82.50	81.68	t	3	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6814	108	24	2024-12-12	3	11.00	0.01	33.00	32.67	t	3	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6815	58	21	2024-12-12	10	34.00	0.03	340.00	329.80	t	3	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6816	84	36	2024-12-12	9	26.50	0.02	238.50	233.73	t	3	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6817	70	3	2024-12-12	8	20.00	0.04	160.00	153.60	t	3	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6818	122	8	2024-12-12	9	40.00	0.02	360.00	352.80	t	3	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6819	64	33	2024-12-13	2	21.00	0.09	42.00	38.22	t	4	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6820	147	8	2024-12-13	1	40.00	0.01	40.00	39.60	t	4	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6821	55	35	2024-12-13	3	63.00	0.07	189.00	175.77	t	4	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6822	48	30	2024-12-13	7	18.00	0.02	126.00	123.48	t	4	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6823	80	27	2024-12-13	5	85.00	0.08	425.00	391.00	t	4	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6824	45	36	2024-12-13	9	26.50	0.10	238.50	214.65	t	4	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6825	61	20	2024-12-13	3	17.00	0.01	51.00	50.49	t	4	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6826	56	32	2024-12-13	2	48.00	0.05	96.00	91.20	t	4	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6827	73	34	2024-12-13	3	9.50	0.07	28.50	26.51	t	4	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6828	9	12	2024-12-13	10	44.00	0.06	440.00	413.60	t	4	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6829	139	44	2024-12-13	10	10.50	0.04	105.00	100.80	t	4	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6830	65	52	2024-12-13	2	47.50	0.03	95.00	92.15	t	4	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6831	105	39	2024-12-13	9	35.00	0.04	315.00	302.40	t	4	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6832	137	9	2024-12-13	10	36.00	0.03	360.00	349.20	t	4	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6833	97	5	2024-12-13	2	60.00	0.06	120.00	112.80	t	4	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6834	70	6	2024-12-13	4	25.00	0.06	100.00	94.00	t	4	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6835	148	36	2024-12-14	10	26.50	0.02	265.00	259.70	t	5	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6836	142	48	2024-12-14	10	44.50	0.01	445.00	440.55	t	5	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6837	140	38	2024-12-14	9	39.00	0.05	351.00	333.45	t	5	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6838	37	40	2024-12-14	3	13.00	0.08	39.00	35.88	t	5	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6839	111	50	2024-12-14	8	17.50	0.02	140.00	137.20	t	5	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6840	137	17	2024-12-14	2	80.00	0.04	160.00	153.60	t	5	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6841	115	5	2024-12-14	2	60.00	0.02	120.00	117.60	t	5	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6842	57	15	2024-12-14	10	70.00	0.01	700.00	693.00	t	5	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6843	94	50	2024-12-14	8	17.50	0.08	140.00	128.80	t	5	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6844	99	21	2024-12-14	7	34.00	0.02	238.00	233.24	t	5	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6845	51	14	2024-12-14	1	12.00	0.01	12.00	11.88	t	5	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6846	136	51	2024-12-14	3	31.50	0.03	94.50	91.66	t	5	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6847	23	5	2024-12-14	6	60.00	0.04	360.00	345.60	t	5	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6848	45	13	2024-12-14	3	23.00	0.09	69.00	62.79	t	5	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6849	146	19	2024-12-14	1	38.00	0.06	38.00	35.72	t	5	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6850	43	48	2024-12-15	5	44.50	0.09	222.50	202.48	t	6	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6851	67	16	2024-12-15	6	26.00	0.02	156.00	152.88	t	6	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6852	46	16	2024-12-15	2	26.00	0.02	52.00	50.96	t	6	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6853	125	41	2024-12-15	8	33.50	0.07	268.00	249.24	t	6	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6854	23	47	2024-12-15	2	82.50	0.09	165.00	150.15	t	6	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6855	130	50	2024-12-15	5	17.50	0.03	87.50	84.88	t	6	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6856	124	21	2024-12-15	10	34.00	0.05	340.00	323.00	t	6	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6857	105	13	2024-12-15	9	23.00	0.04	207.00	198.72	t	6	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6858	74	47	2024-12-15	6	82.50	0.06	495.00	465.30	t	6	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6859	36	22	2024-12-15	4	54.00	0.01	216.00	213.84	t	6	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6860	14	8	2024-12-15	5	40.00	0.05	200.00	190.00	t	6	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6861	85	27	2024-12-15	10	85.00	0.06	850.00	799.00	t	6	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6862	138	21	2024-12-15	8	34.00	0.04	272.00	261.12	t	6	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6863	88	52	2024-12-15	7	47.50	0.01	332.50	329.18	t	6	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6864	144	33	2024-12-15	8	21.00	0.03	168.00	162.96	t	6	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6865	88	9	2024-12-15	10	36.00	0.03	360.00	349.20	t	6	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6866	94	11	2024-12-15	6	32.00	0.04	192.00	184.32	t	6	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6867	119	20	2024-12-16	9	17.00	0.05	153.00	145.35	t	0	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6868	144	45	2024-12-16	4	59.50	0.06	238.00	223.72	t	0	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6869	54	3	2024-12-16	7	20.00	0.00	140.00	140.00	f	0	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6870	51	11	2024-12-16	6	32.00	0.00	192.00	192.00	f	0	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6871	98	44	2024-12-16	9	10.50	0.00	94.50	94.50	f	0	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6872	40	25	2024-12-16	9	65.00	0.00	585.00	585.00	f	0	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6873	25	16	2024-12-16	2	26.00	0.04	52.00	49.92	t	0	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6874	6	23	2024-12-16	8	24.00	0.07	192.00	178.56	t	0	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6875	98	17	2024-12-16	3	80.00	0.01	240.00	237.60	t	0	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6876	3	27	2024-12-16	10	85.00	0.07	850.00	790.50	t	0	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6877	7	9	2024-12-17	3	36.00	0.04	108.00	103.68	t	1	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6878	123	49	2024-12-17	7	39.50	0.08	276.50	254.38	t	1	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6879	57	50	2024-12-17	4	17.50	0.04	70.00	67.20	t	1	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6880	54	51	2024-12-17	1	31.50	0.08	31.50	28.98	t	1	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6881	18	45	2024-12-17	5	59.50	0.01	297.50	294.53	t	1	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6882	36	33	2024-12-17	5	21.00	0.00	105.00	105.00	f	1	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6883	42	53	2024-12-17	5	22.50	0.03	112.50	109.13	t	1	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6884	33	37	2024-12-17	7	88.00	0.01	616.00	609.84	t	1	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6885	86	26	2024-12-17	10	22.00	0.06	220.00	206.80	t	1	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6886	75	6	2024-12-17	7	25.00	0.04	175.00	168.00	t	1	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6887	38	49	2024-12-17	9	39.50	0.05	355.50	337.72	t	1	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6888	39	20	2024-12-17	7	17.00	0.04	119.00	114.24	t	1	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6889	147	34	2024-12-17	5	9.50	0.04	47.50	45.60	t	1	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6890	2	25	2024-12-17	5	65.00	0.03	325.00	315.25	t	1	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6891	28	26	2024-12-18	3	22.00	0.03	66.00	64.02	t	2	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6892	113	18	2024-12-18	1	43.00	0.07	43.00	39.99	t	2	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6893	2	20	2024-12-18	1	17.00	0.08	17.00	15.64	t	2	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6894	21	53	2024-12-18	5	22.50	0.06	112.50	105.75	t	2	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6895	131	26	2024-12-18	3	22.00	0.05	66.00	62.70	t	2	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6896	130	50	2024-12-18	5	17.50	0.05	87.50	83.13	t	2	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6897	2	39	2024-12-18	7	35.00	0.07	245.00	227.85	t	2	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6898	113	12	2024-12-18	4	44.00	0.09	176.00	160.16	t	2	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6899	75	45	2024-12-18	2	59.50	0.07	119.00	110.67	t	2	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6900	103	44	2024-12-18	10	10.50	0.03	105.00	101.85	t	2	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6901	51	36	2024-12-18	9	26.50	0.02	238.50	233.73	t	2	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6902	116	53	2024-12-18	10	22.50	0.04	225.00	216.00	t	2	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6903	105	21	2024-12-18	6	34.00	0.09	204.00	185.64	t	2	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6904	127	46	2024-12-18	2	25.50	0.07	51.00	47.43	t	2	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6905	85	31	2024-12-18	6	37.00	0.01	222.00	219.78	t	2	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6906	141	48	2024-12-18	3	44.50	0.02	133.50	130.83	t	2	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6907	141	19	2024-12-18	10	38.00	0.03	380.00	368.60	t	2	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6908	136	40	2024-12-18	7	13.00	0.03	91.00	88.27	t	2	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6909	144	50	2024-12-18	10	17.50	0.06	175.00	164.50	t	2	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6910	118	53	2024-12-19	4	22.50	0.03	90.00	87.30	t	3	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6911	123	27	2024-12-19	4	85.00	0.07	340.00	316.20	t	3	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6912	67	35	2024-12-19	7	63.00	0.10	441.00	396.90	t	3	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6913	5	26	2024-12-19	4	22.00	0.08	88.00	80.96	t	3	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6914	80	35	2024-12-19	3	63.00	0.05	189.00	179.55	t	3	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6915	81	35	2024-12-19	9	63.00	0.02	567.00	555.66	t	3	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6916	150	38	2024-12-19	6	39.00	0.01	234.00	231.66	t	3	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6917	22	20	2024-12-19	8	17.00	0.09	136.00	123.76	t	3	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6918	127	45	2024-12-19	5	59.50	0.01	297.50	294.53	t	3	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6919	77	25	2024-12-19	7	65.00	0.06	455.00	427.70	t	3	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6920	51	51	2024-12-19	3	31.50	0.07	94.50	87.88	t	3	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6921	67	11	2024-12-19	7	32.00	0.03	224.00	217.28	t	3	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6922	82	50	2024-12-19	3	17.50	0.01	52.50	51.98	t	3	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6923	101	32	2024-12-19	4	48.00	0.02	192.00	188.16	t	3	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6924	45	21	2024-12-19	5	34.00	0.06	170.00	159.80	t	3	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6925	22	23	2024-12-19	1	24.00	0.08	24.00	22.08	t	3	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6926	84	37	2024-12-19	10	88.00	0.07	880.00	818.40	t	3	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6927	72	41	2024-12-19	6	33.50	0.00	201.00	201.00	f	3	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6928	45	14	2024-12-19	6	12.00	0.05	72.00	68.40	t	3	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6929	32	31	2024-12-19	8	37.00	0.04	296.00	284.16	t	3	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6930	69	45	2024-12-19	9	59.50	0.07	535.50	498.02	t	3	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6931	9	52	2024-12-19	1	47.50	0.07	47.50	44.18	t	3	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6932	74	4	2024-12-20	4	10.00	0.07	40.00	37.20	t	4	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6933	23	23	2024-12-20	2	24.00	0.04	48.00	46.08	t	4	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6934	56	9	2024-12-20	8	36.00	0.03	288.00	279.36	t	4	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6935	95	22	2024-12-20	5	54.00	0.07	270.00	251.10	t	4	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6936	102	1	2024-12-20	4	30.00	0.04	120.00	115.20	t	4	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6937	37	46	2024-12-20	4	25.50	0.07	102.00	94.86	t	4	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6938	109	24	2024-12-20	5	11.00	0.02	55.00	53.90	t	4	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6939	13	30	2024-12-20	7	18.00	0.05	126.00	119.70	t	4	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6940	125	31	2024-12-20	10	37.00	0.07	370.00	344.10	t	4	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6941	18	38	2024-12-20	5	39.00	0.04	195.00	187.20	t	4	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6942	128	29	2024-12-21	5	40.00	0.10	200.00	180.00	t	5	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6943	101	34	2024-12-21	7	9.50	0.02	66.50	65.17	t	5	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6944	43	31	2024-12-21	4	37.00	0.08	148.00	136.16	t	5	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6945	47	31	2024-12-21	1	37.00	0.06	37.00	34.78	t	5	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6946	66	49	2024-12-21	9	39.50	0.08	355.50	327.06	t	5	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6947	17	14	2024-12-21	3	12.00	0.00	36.00	36.00	f	5	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6948	70	15	2024-12-21	4	70.00	0.06	280.00	263.20	t	5	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6949	114	43	2024-12-21	3	28.00	0.07	84.00	78.12	t	5	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6950	85	32	2024-12-21	10	48.00	0.05	480.00	456.00	t	5	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6951	90	26	2024-12-21	8	22.00	0.03	176.00	170.72	t	5	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6952	89	38	2024-12-21	8	39.00	0.08	312.00	287.04	t	5	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6953	10	21	2024-12-21	4	34.00	0.06	136.00	127.84	t	5	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6954	31	2	2024-12-21	9	50.00	0.07	450.00	418.50	t	5	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6955	37	18	2024-12-21	4	43.00	0.08	172.00	158.24	t	5	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6956	126	4	2024-12-21	4	10.00	0.07	40.00	37.20	t	5	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6957	10	33	2024-12-22	3	21.00	0.10	63.00	56.70	t	6	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6958	33	33	2024-12-22	10	21.00	0.03	210.00	203.70	t	6	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6959	95	38	2024-12-22	10	39.00	0.01	390.00	386.10	t	6	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6960	66	3	2024-12-22	1	20.00	0.03	20.00	19.40	t	6	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6961	79	44	2024-12-22	7	10.50	0.00	73.50	73.50	f	6	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6962	139	42	2024-12-22	5	53.00	0.05	265.00	251.75	t	6	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6963	81	41	2024-12-22	9	33.50	0.02	301.50	295.47	t	6	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6964	64	8	2024-12-22	10	40.00	0.05	400.00	380.00	t	6	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6965	11	24	2024-12-22	1	11.00	0.04	11.00	10.56	t	6	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6966	122	1	2024-12-22	4	30.00	0.04	120.00	115.20	t	6	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6967	47	48	2024-12-22	4	44.50	0.01	178.00	176.22	t	6	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6968	150	51	2024-12-22	9	31.50	0.06	283.50	266.49	t	6	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6969	120	41	2024-12-22	1	33.50	0.09	33.50	30.49	t	6	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6970	145	13	2024-12-22	1	23.00	0.06	23.00	21.62	t	6	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6971	139	52	2024-12-22	9	47.50	0.05	427.50	406.13	t	6	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6972	53	27	2024-12-22	7	85.00	0.10	595.00	535.50	t	6	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6973	56	7	2024-12-23	3	90.00	0.09	270.00	245.70	t	0	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6974	27	38	2024-12-23	10	39.00	0.05	390.00	370.50	t	0	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6975	42	32	2024-12-23	7	48.00	0.03	336.00	325.92	t	0	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6976	144	22	2024-12-23	3	54.00	0.05	162.00	153.90	t	0	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6977	36	46	2024-12-23	5	25.50	0.07	127.50	118.57	t	0	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6978	94	51	2024-12-23	2	31.50	0.04	63.00	60.48	t	0	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6979	3	45	2024-12-23	10	59.50	0.03	595.00	577.15	t	0	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6980	35	28	2024-12-23	7	46.00	0.04	322.00	309.12	t	0	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6981	129	7	2024-12-23	3	90.00	0.08	270.00	248.40	t	0	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6982	77	20	2024-12-23	4	17.00	0.09	68.00	61.88	t	0	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6983	49	31	2024-12-23	7	37.00	0.07	259.00	240.87	t	0	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6984	9	6	2024-12-23	4	25.00	0.08	100.00	92.00	t	0	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6985	130	6	2024-12-23	9	25.00	0.02	225.00	220.50	t	0	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6986	38	11	2024-12-23	3	32.00	0.02	96.00	94.08	t	0	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6987	125	18	2024-12-23	8	43.00	0.00	344.00	344.00	f	0	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6988	4	43	2024-12-23	10	28.00	0.01	280.00	277.20	t	0	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6989	53	52	2024-12-24	7	47.50	0.07	332.50	309.22	t	1	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6990	84	44	2024-12-24	2	10.50	0.08	21.00	19.32	t	1	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6991	79	3	2024-12-24	1	20.00	0.06	20.00	18.80	t	1	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6992	3	24	2024-12-24	10	11.00	0.10	110.00	99.00	t	1	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6993	47	45	2024-12-24	5	59.50	0.05	297.50	282.63	t	1	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6994	30	4	2024-12-24	7	10.00	0.10	70.00	63.00	t	1	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6995	21	7	2024-12-24	4	90.00	0.00	360.00	360.00	f	1	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6996	21	52	2024-12-24	2	47.50	0.07	95.00	88.35	t	1	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6997	90	53	2024-12-24	8	22.50	0.03	180.00	174.60	t	1	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6998	72	19	2024-12-24	10	38.00	0.01	380.00	376.20	t	1	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
6999	66	13	2024-12-24	4	23.00	0.07	92.00	85.56	t	1	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7000	19	39	2024-12-24	5	35.00	0.00	175.00	175.00	f	1	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7001	105	22	2024-12-24	6	54.00	0.03	324.00	314.28	t	1	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7002	32	9	2024-12-24	3	36.00	0.02	108.00	105.84	t	1	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7003	134	18	2024-12-24	10	43.00	0.01	430.00	425.70	t	1	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7004	68	23	2024-12-24	7	24.00	0.03	168.00	162.96	t	1	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7005	38	37	2024-12-24	9	88.00	0.03	792.00	768.24	t	1	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7006	120	18	2024-12-24	7	43.00	0.07	301.00	279.93	t	1	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7007	89	2	2024-12-24	9	50.00	0.01	450.00	445.50	t	1	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7008	93	35	2024-12-24	5	63.00	0.09	315.00	286.65	t	1	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7009	72	25	2024-12-24	9	65.00	0.08	585.00	538.20	t	1	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7010	144	44	2024-12-24	2	10.50	0.02	21.00	20.58	t	1	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7011	113	22	2024-12-24	4	54.00	0.07	216.00	200.88	t	1	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7012	125	26	2024-12-24	6	22.00	0.02	132.00	129.36	t	1	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7013	33	22	2024-12-24	3	54.00	0.01	162.00	160.38	t	1	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7014	12	33	2024-12-25	1	21.00	0.04	21.00	20.16	t	2	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7015	114	18	2024-12-25	10	43.00	0.09	430.00	391.30	t	2	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7016	24	32	2024-12-25	5	48.00	0.07	240.00	223.20	t	2	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7017	10	19	2024-12-25	5	38.00	0.07	190.00	176.70	t	2	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7018	20	35	2024-12-25	6	63.00	0.09	378.00	343.98	t	2	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7019	11	49	2024-12-25	1	39.50	0.05	39.50	37.53	t	2	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7020	94	14	2024-12-25	9	12.00	0.06	108.00	101.52	t	2	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7021	143	34	2024-12-25	2	9.50	0.09	19.00	17.29	t	2	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7022	21	11	2024-12-25	3	32.00	0.05	96.00	91.20	t	2	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7023	34	22	2024-12-25	2	54.00	0.07	108.00	100.44	t	2	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7024	32	20	2024-12-25	8	17.00	0.03	136.00	131.92	t	2	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7025	46	16	2024-12-25	8	26.00	0.04	208.00	199.68	t	2	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7026	103	25	2024-12-25	6	65.00	0.05	390.00	370.50	t	2	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7027	43	21	2024-12-25	3	34.00	0.06	102.00	95.88	t	2	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7028	125	12	2024-12-25	8	44.00	0.03	352.00	341.44	t	2	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7029	150	44	2024-12-25	1	10.50	0.07	10.50	9.76	t	2	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7030	4	49	2024-12-25	10	39.50	0.02	395.00	387.10	t	2	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7031	93	25	2024-12-25	8	65.00	0.07	520.00	483.60	t	2	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7032	51	52	2024-12-25	10	47.50	0.03	475.00	460.75	t	2	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7033	82	27	2024-12-25	8	85.00	0.07	680.00	632.40	t	2	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7034	107	20	2024-12-25	2	17.00	0.03	34.00	32.98	t	2	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7035	36	4	2024-12-26	10	10.00	0.01	100.00	99.00	t	3	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7036	90	40	2024-12-26	3	13.00	0.02	39.00	38.22	t	3	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7037	9	36	2024-12-26	10	26.50	0.02	265.00	259.70	t	3	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7038	23	18	2024-12-26	3	43.00	0.08	129.00	118.68	t	3	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7039	100	50	2024-12-26	2	17.50	0.01	35.00	34.65	t	3	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7040	16	37	2024-12-26	8	88.00	0.04	704.00	675.84	t	3	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7041	141	43	2024-12-26	9	28.00	0.05	252.00	239.40	t	3	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7042	141	13	2024-12-26	4	23.00	0.00	92.00	92.00	f	3	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7043	46	34	2024-12-26	3	9.50	0.03	28.50	27.65	t	3	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7044	34	23	2024-12-26	5	24.00	0.08	120.00	110.40	t	3	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7045	8	20	2024-12-26	10	17.00	0.06	170.00	159.80	t	3	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7046	92	52	2024-12-26	10	47.50	0.10	475.00	427.50	t	3	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7047	140	51	2024-12-26	10	31.50	0.00	315.00	315.00	f	3	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7048	54	23	2024-12-26	9	24.00	0.08	216.00	198.72	t	3	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7049	70	34	2024-12-26	7	9.50	0.04	66.50	63.84	t	3	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7050	86	46	2024-12-26	6	25.50	0.10	153.00	137.70	t	3	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7051	132	27	2024-12-26	8	85.00	0.09	680.00	618.80	t	3	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7052	94	47	2024-12-26	6	82.50	0.09	495.00	450.45	t	3	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7053	89	33	2024-12-26	7	21.00	0.09	147.00	133.77	t	3	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7054	12	48	2024-12-26	4	44.50	0.04	178.00	170.88	t	3	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7055	136	53	2024-12-27	2	22.50	0.09	45.00	40.95	t	4	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7056	20	7	2024-12-27	5	90.00	0.06	450.00	423.00	t	4	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7057	81	16	2024-12-27	5	26.00	0.01	130.00	128.70	t	4	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7058	106	45	2024-12-27	2	59.50	0.02	119.00	116.62	t	4	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7059	96	23	2024-12-27	2	24.00	0.05	48.00	45.60	t	4	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7060	112	13	2024-12-27	8	23.00	0.09	184.00	167.44	t	4	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7061	57	44	2024-12-27	10	10.50	0.08	105.00	96.60	t	4	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7062	23	19	2024-12-27	1	38.00	0.02	38.00	37.24	t	4	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7063	75	19	2024-12-27	9	38.00	0.07	342.00	318.06	t	4	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7064	80	38	2024-12-27	4	39.00	0.09	156.00	141.96	t	4	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7065	16	12	2024-12-27	3	44.00	0.04	132.00	126.72	t	4	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7066	58	25	2024-12-27	1	65.00	0.10	65.00	58.50	t	4	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7067	34	5	2024-12-27	3	60.00	0.00	180.00	180.00	f	4	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7068	68	45	2024-12-27	5	59.50	0.02	297.50	291.55	t	4	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7069	40	44	2024-12-27	5	10.50	0.10	52.50	47.25	t	4	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7070	69	53	2024-12-27	8	22.50	0.00	180.00	180.00	f	4	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7071	18	28	2024-12-27	2	46.00	0.02	92.00	90.16	t	4	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7072	29	2	2024-12-27	9	50.00	0.03	450.00	436.50	t	4	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7073	122	22	2024-12-27	10	54.00	0.07	540.00	502.20	t	4	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7074	134	49	2024-12-28	1	39.50	0.04	39.50	37.92	t	5	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7075	18	21	2024-12-28	9	34.00	0.00	306.00	306.00	f	5	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7076	80	6	2024-12-28	9	25.00	0.06	225.00	211.50	t	5	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7077	113	33	2024-12-28	6	21.00	0.01	126.00	124.74	t	5	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7078	111	2	2024-12-28	1	50.00	0.02	50.00	49.00	t	5	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7079	2	30	2024-12-28	6	18.00	0.03	108.00	104.76	t	5	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7080	120	13	2024-12-28	7	23.00	0.08	161.00	148.12	t	5	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7081	116	19	2024-12-28	6	38.00	0.05	228.00	216.60	t	5	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7082	116	6	2024-12-28	10	25.00	0.04	250.00	240.00	t	5	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7083	85	18	2024-12-28	6	43.00	0.05	258.00	245.10	t	5	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7084	45	41	2024-12-28	3	33.50	0.04	100.50	96.48	t	5	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7085	106	13	2024-12-28	3	23.00	0.06	69.00	64.86	t	5	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7086	54	10	2024-12-28	2	15.00	0.04	30.00	28.80	t	5	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7087	27	2	2024-12-28	9	50.00	0.07	450.00	418.50	t	5	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7088	37	2	2024-12-28	5	50.00	0.08	250.00	230.00	t	5	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7089	119	21	2024-12-29	2	34.00	0.01	68.00	67.32	t	6	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7090	110	7	2024-12-29	1	90.00	0.03	90.00	87.30	t	6	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7091	149	7	2024-12-29	2	90.00	0.03	180.00	174.60	t	6	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7092	121	16	2024-12-29	3	26.00	0.06	78.00	73.32	t	6	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7093	95	10	2024-12-29	8	15.00	0.04	120.00	115.20	t	6	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7094	59	29	2024-12-29	6	40.00	0.08	240.00	220.80	t	6	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7095	49	41	2024-12-29	5	33.50	0.09	167.50	152.43	t	6	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7096	66	22	2024-12-29	2	54.00	0.09	108.00	98.28	t	6	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7097	4	49	2024-12-29	6	39.50	0.03	237.00	229.89	t	6	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7098	134	8	2024-12-29	5	40.00	0.00	200.00	200.00	f	6	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7099	104	52	2024-12-29	6	47.50	0.04	285.00	273.60	t	6	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7100	71	46	2024-12-29	3	25.50	0.06	76.50	71.91	t	6	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7101	37	52	2024-12-29	9	47.50	0.04	427.50	410.40	t	6	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7102	21	45	2024-12-29	2	59.50	0.00	119.00	119.00	f	6	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7103	102	12	2024-12-29	8	44.00	0.10	352.00	316.80	t	6	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7104	82	29	2024-12-29	2	40.00	0.05	80.00	76.00	t	6	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7105	139	37	2024-12-29	2	88.00	0.03	176.00	170.72	t	6	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7106	89	26	2024-12-29	1	22.00	0.02	22.00	21.56	t	6	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7107	100	33	2024-12-29	1	21.00	0.01	21.00	20.79	t	6	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7108	50	24	2024-12-29	8	11.00	0.02	88.00	86.24	t	6	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7109	117	42	2024-12-29	3	53.00	0.05	159.00	151.05	t	6	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7110	123	13	2024-12-29	4	23.00	0.02	92.00	90.16	t	6	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7111	67	25	2024-12-30	10	65.00	0.03	650.00	630.50	t	0	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7112	112	40	2024-12-30	7	13.00	0.03	91.00	88.27	t	0	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7113	127	45	2024-12-30	3	59.50	0.04	178.50	171.36	t	0	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7114	112	25	2024-12-30	1	65.00	0.07	65.00	60.45	t	0	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7115	62	24	2024-12-30	5	11.00	0.02	55.00	53.90	t	0	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7116	137	51	2024-12-30	6	31.50	0.08	189.00	173.88	t	0	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7117	11	35	2024-12-30	4	63.00	0.10	252.00	226.80	t	0	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7118	141	53	2024-12-30	1	22.50	0.05	22.50	21.38	t	0	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7119	8	38	2024-12-30	1	39.00	0.00	39.00	39.00	f	0	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7120	76	47	2024-12-30	8	82.50	0.01	660.00	653.40	t	0	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7121	19	26	2024-12-30	4	22.00	0.02	88.00	86.24	t	0	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7122	49	27	2024-12-30	4	85.00	0.07	340.00	316.20	t	0	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7123	12	30	2024-12-30	3	18.00	0.10	54.00	48.60	t	0	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7124	5	34	2024-12-30	7	9.50	0.08	66.50	61.18	t	0	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7125	126	47	2024-12-30	3	82.50	0.04	247.50	237.60	t	0	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7126	109	14	2024-12-30	5	12.00	0.08	60.00	55.20	t	0	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7127	30	13	2024-12-30	4	23.00	0.01	92.00	91.08	t	0	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7128	77	14	2024-12-31	3	12.00	0.04	36.00	34.56	t	1	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7129	38	28	2024-12-31	9	46.00	0.06	414.00	389.16	t	1	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7130	47	33	2024-12-31	4	21.00	0.07	84.00	78.12	t	1	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7131	130	9	2024-12-31	1	36.00	0.02	36.00	35.28	t	1	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7132	35	17	2024-12-31	7	80.00	0.10	560.00	504.00	t	1	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7133	36	17	2024-12-31	3	80.00	0.04	240.00	230.40	t	1	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7134	46	26	2024-12-31	1	22.00	0.05	22.00	20.90	t	1	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
7135	2	39	2024-12-31	3	35.00	0.04	105.00	100.80	t	1	12	2024	2026-03-22 15:19:45.057077	2026-03-22 17:49:45.932197
\.


--
-- Data for Name: dwh_high_water_mark; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.dwh_high_water_mark (id, table_name, last_updated, created_at, updated_at) FROM stdin;
2	products	2026-03-22 15:19:45.5684	2026-03-22 17:48:19.977625	2026-03-22 17:48:19.977625
1	customers	2026-03-22 15:19:45.626884	2026-03-22 17:48:19.977625	2026-03-22 17:48:19.977625
3	sales	2026-03-22 15:19:45.057077	2026-03-22 17:48:19.977625	2026-03-22 17:48:19.977625
\.


--
-- Name: dwh_etl_logs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.dwh_etl_logs_id_seq', 1, false);


--
-- Name: dwh_high_water_mark_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.dwh_high_water_mark_id_seq', 3, true);


--
-- Name: dwh_dim_customers dwh_dim_customers_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dwh_dim_customers
    ADD CONSTRAINT dwh_dim_customers_pkey PRIMARY KEY (id, valid_from);


--
-- Name: dwh_dim_products dwh_dim_products_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dwh_dim_products
    ADD CONSTRAINT dwh_dim_products_pkey PRIMARY KEY (id, valid_from);


--
-- Name: dwh_etl_logs dwh_etl_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dwh_etl_logs
    ADD CONSTRAINT dwh_etl_logs_pkey PRIMARY KEY (id);


--
-- Name: dwh_fact_sales dwh_fact_sales_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dwh_fact_sales
    ADD CONSTRAINT dwh_fact_sales_pkey PRIMARY KEY (sales_id);


--
-- Name: dwh_high_water_mark dwh_high_water_mark_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dwh_high_water_mark
    ADD CONSTRAINT dwh_high_water_mark_pkey PRIMARY KEY (id);


--
-- Name: dwh_high_water_mark dwh_high_water_mark_table_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dwh_high_water_mark
    ADD CONSTRAINT dwh_high_water_mark_table_name_key UNIQUE (table_name);


--
-- PostgreSQL database dump complete
--

\unrestrict FfUfX7F05aKhDWkuhoRRcUVwu6jKqTS1UlVkAgt2c4sIEKUR8bYvGMrc4MjCuXa

