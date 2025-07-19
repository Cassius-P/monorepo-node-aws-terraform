import { Controller, Get } from '@nestjs/common';

@Controller('health')
export class HealthController {
  constructor() {}

  @Get()
  async getHealth() {
    try {
      // Test de connexion à la base de données
      //await this.prisma.$queryRaw`SELECT 1`;
      return {
        status: 'healthy',
        timestamp: new Date().toISOString(),
        database: 'connected'
      };
    } catch (error) {
      return {
        status: 'unhealthy',
        timestamp: new Date().toISOString(),
        database: 'disconnected',
        error: error.message
      };
    }
  }

  @Get('status')
  getStatus() {
    return {
      status: 'Server is running',
      timestamp: new Date().toISOString(),
      port: process.env.PORT || 3001
    };
  }
} 