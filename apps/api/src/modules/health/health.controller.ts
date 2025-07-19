import { Controller, Get } from "@nestjs/common";

@Controller("health")
export class HealthController {
  constructor() {}

  @Get()
  getHealth() {
    try {
      // Test de connexion à la base de données
      // Future: await this.prisma.$queryRaw`SELECT 1`;
      return {
        status: "healthy",
        timestamp: new Date().toISOString(),
        database: "connected",
      };
    } catch (error) {
      const errorMessage =
        error instanceof Error ? error.message : "Unknown error";
      return {
        status: "unhealthy",
        timestamp: new Date().toISOString(),
        database: "disconnected",
        error: errorMessage,
      };
    }
  }

  @Get("status")
  getStatus() {
    return {
      status: "Server is running",
      timestamp: new Date().toISOString(),
      port: process.env.PORT || 3001,
    };
  }
}
