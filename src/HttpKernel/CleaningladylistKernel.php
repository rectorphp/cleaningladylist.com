<?php

declare(strict_types=1);

namespace App\HttpKernel;

use Symfony\Bundle\FrameworkBundle\Kernel\MicroKernelTrait;
use Symfony\Component\Config\Loader\LoaderInterface;
use Symfony\Component\DependencyInjection\ContainerBuilder;
use Symfony\Component\HttpKernel\Kernel;
use Symfony\Component\Routing\Loader\Configurator\RoutingConfigurator;
use Symplify\FlexLoader\Flex\FlexLoader;
use Symplify\SmartFileSystem\SmartFileSystem;

final class CleaningladylistKernel extends Kernel
{
    use MicroKernelTrait;

    /**
     * @var FlexLoader
     */
    private $flexLoader;

    public function __construct(string $environment, bool $debug)
    {
        parent::__construct($environment, $debug);

        $this->flexLoader = new FlexLoader($environment, $this->getProjectDir());
    }

    public function registerBundles(): iterable
    {
        return $this->flexLoader->loadBundles();
    }

    protected function configureContainer(ContainerBuilder $containerBuilder, LoaderInterface $loader): void
    {
        $this->flexLoader->loadConfigs($containerBuilder, $loader);
    }

    /**
     * If routing gets broken, debug command will help to narrow the issue:
     * bin/console debug:router
     */
    protected function configureRoutes(RoutingConfigurator $routingConfigurator): void
    {
        $routingConfigurator->import(__DIR__ . '/../../config/routes/*.php');

        // must be checked
        $smartFileSystem = new SmartFileSystem();
        if ($smartFileSystem->exists(__DIR__ . '/../../config/routes/' . $this->environment)) {
            $routingConfigurator->import(__DIR__ . '/../../config/routes/' . $this->environment . '/*.php');
        }
    }
}
