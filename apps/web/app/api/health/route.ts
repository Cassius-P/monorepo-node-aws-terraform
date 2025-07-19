import { NextRequest, NextResponse } from 'next/server';

export async function GET(request: NextRequest) {
  try {
    // Basic health check information
    const healthCheck = {
      status: 'ok',
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
      environment: process.env.NODE_ENV || 'development',
      version: process.env.npm_package_version || '1.0.0',
      service: 'web',
      checks: {
        server: 'healthy'
      }
    };

    return NextResponse.json(healthCheck, { status: 200 });
  } catch (error) {
    const errorResponse = {
      status: 'error',
      timestamp: new Date().toISOString(),
      error: error instanceof Error ? error.message : 'Unknown error',
      service: 'web'
    };

    return NextResponse.json(errorResponse, { status: 503 });
  }
}

// Optional: Add a simple status endpoint for basic checks
export async function HEAD(request: NextRequest) {
  return new NextResponse(null, { status: 200 });
}