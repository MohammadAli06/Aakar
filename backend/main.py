"""
Aakar FastAPI Backend — Main Application
SIH 2026 · PS 26090 · MoSJE
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager

from app.routers import auth, products, catalog, pricing, b2b
from app.core.config import settings
from app.core.database import engine, Base


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: create tables
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield
    # Shutdown: cleanup


def create_app() -> FastAPI:
    app = FastAPI(
        title="Aakar API",
        description="AI-Driven Market Linkage & Smart Cataloging for Marginalized Artisans",
        version="1.0.0",
        docs_url="/docs",
        redoc_url="/redoc",
        lifespan=lifespan,
    )

    # CORS — allow Flutter app + web dashboard
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],  # Restrict in production
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    # Include routers
    app.include_router(auth.router, prefix="/api/v1/auth", tags=["Auth"])
    app.include_router(products.router, prefix="/api/v1/products", tags=["Products"])
    app.include_router(catalog.router, prefix="/api/v1/catalog", tags=["Catalog"])
    app.include_router(pricing.router, prefix="/api/v1/pricing", tags=["Pricing"])
    app.include_router(b2b.router, prefix="/api/v1/b2b", tags=["B2B"])

    @app.get("/health")
    async def health():
        return {"status": "ok", "service": "Aakar API"}

    return app


app = create_app()
